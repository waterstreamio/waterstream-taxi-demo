package io.simplematter.waterstream.vehiclesimulator.verticles

import io.netty.handler.codec.mqtt.MqttQoS
import io.simplematter.waterstream.vehiclesimulator.config.MqttConfig
import io.simplematter.waterstream.vehiclesimulator.domain.*
import io.simplematter.waterstream.vehiclesimulator.events.FleetEvent
import io.simplematter.waterstream.vehiclesimulator.monitoring.VehicleSimCounters
import io.simplematter.waterstream.vehiclesimulator.tools.JsonUtils
import io.simplematter.waterstream.vehiclesimulator.tools.MqttConnect
import io.simplematter.waterstream.vehiclesimulator.tools.RouteGenerator
import io.vertx.core.Handler
import io.vertx.core.buffer.Buffer
import io.vertx.core.eventbus.Message
import io.vertx.kotlin.coroutines.CoroutineVerticle
import java.time.Instant
import kotlin.random.Random
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.slf4j.LoggerFactory
import java.util.concurrent.atomic.AtomicBoolean

class VehicleVerticle : CoroutineVerticle() {

    companion object {
        private val log = LoggerFactory.getLogger(VehicleVerticle::class.java.name)

        data class VehicleConfig(
            val id: String,
            val plate: String,
            val visible: Boolean,
            val mqttConfig: MqttConfig,
            val routingUrl: String
        )
    }

    private val vehicleConfig: VehicleConfig by lazy {
        JsonUtils.fromVertxJson(config, VehicleConfig::class.java)
    }

    private lateinit var vehicle: Vehicle
    private val routingUrl by lazy { vehicleConfig.routingUrl }

    private var timer: Long = 0
    private val refreshTimeMillis: Long = 500
    private var waitCycles = 0

    private val routeGenerator by lazy { RouteGenerator(routingUrl) }
    private var currentRoute = listOf<Point>()

    private var assignedRoute = listOf<Point>()


    private val id by lazy { vehicleConfig.id }
    private val plate by lazy { vehicleConfig.plate }
    private val tickEvent by lazy { "Vehicle.$plate.Ticked" }

    private val topicPrefix by lazy { vehicleConfig.mqttConfig.topicPrefix }

    private var wayBack = false

    private val mqttConnect by lazy {
        MqttConnect(
            vertx,
            vehicleConfig.mqttConfig.host,
            vehicleConfig.mqttConfig.port,
            "$plate $deploymentID",
            vehicleConfig.mqttConfig.username,
            vehicleConfig.mqttConfig.password
        )
    }

    @Volatile
    private var undeployRequested = false

    private val vehicleMutex = Mutex()

    override suspend fun start() {
        log.debug("Starting {} {} vehicle initialization", plate, id)

        val companyColors = listOf( // TODO move lists to config?
            "blue",
            "red",
            "green",
            "yellow",
            "cyan",
            "magenta",
            "violet",
            "orange",
            "black",
            "pink"
        )

        val companyNames = listOf(
            "WaterstreamTaxi",
            "RedPandaCabs",
            "StreamDrive",
            "SimpleTaxi",
            "MaterializeCabs",
            "NYCAirportService",
            "KafkaLimousine",
            "VectorizedCityCabs",
            "RadioTaxi",
            "BrooklynYellowCars"
        )

        val companyShapes = listOf(
            "circle",
            "circle",
            "circle",
            "circle",
            "circle",
            "square",
            "square",
            "square",
            "square",
            "square"
        )

        try {
            assignedRoute = routeGenerator.generateRoute()
            currentRoute = assignedRoute.drop(1)
            val companyRandomIndex = Random.nextInt(companyNames.size)

            vehicle = Vehicle(
                plate,
                current = assignedRoute.first(),
                waypoint = currentRoute.first(),
                updateTimestamp = Instant.now().toEpochMilli(),
                speed = Random.nextDouble(30.0, 60.0),
                visible = vehicleConfig.visible,
                passengers = Random.nextInt(1, 4),
                companyName = companyNames[companyRandomIndex],
                companyColor = companyColors[companyRandomIndex],
                companyShape = companyShapes[companyRandomIndex],
                isHired = true,
                id = id
            )
            currentRoute = assignedRoute.drop(1)

            VehicleSimCounters.vehiclesCreateAttempts.inc()
            vertx.eventBus().publish(FleetEvent.VehicleCreated, vehicle.toJson())

            publishCompanyPassengersUpdateToMqtt()

            timer = vertx.setPeriodic(refreshTimeMillis) {
                vertx.eventBus().publish(tickEvent, plate)
            }

            vertx.eventBus().consumer(tickEvent, Handler<Message<String>> { event ->
                GlobalScope.launch(Dispatchers.IO) { handle(event) }
            })

            mqttConnect.getConnectedMqttClient()
        } catch (e: Exception) {
            log.info("${plate} will be removed because of initialization error")
            VehicleSimCounters.vehicleInitErrors.inc()
            undeployVerticle()
        }
        VehicleSimCounters.vehiclesCreated.inc()
        VehicleSimCounters.vehiclesCurrent.inc()

        log.debug("Finished $plate $deploymentID vehicle initialization")
    }

    private suspend fun handle(event: Message<String>) {
        vehicleMutex.withLock {
            if (waitCycles == 0) {
                if (!vehicle.isArrived()) {
                    val now = Instant.now().toEpochMilli()
                    val elapsed = now - vehicle.updateTimestamp

                    vehicle = vehicle.updatePosition(elapsed)

                    if(!vehicle.isHired) {
                        vehicle.isHired = true
                        publishCompanyPassengersUpdateToMqtt()
                    }
                    vertx.eventBus().publish(FleetEvent.VehicleUpdated, vehicle.toJson())
                    VehicleSimCounters.vehicleUpdates.inc()
                    publishVehicleUpdateToMqtt()
                } else {
                    VehicleSimCounters.vehicleArriveEvents.inc()
                    if (currentRoute.isEmpty()) {
                        // this pauses the vehicle for a while before starting a new route
                        waitCycles = Random.nextInt(100)
                        if (wayBack) {
                            currentRoute = assignedRoute.asReversed()
                        } else {
                            currentRoute = assignedRoute
                        }
                        wayBack = !wayBack
                    }

                    if (vehicle.isHired) {
                        vehicle.isHired = false
                        publishCompanyPassengersUpdateToMqtt()
                    }

                    val newWaypoint = currentRoute.first()
                    val distanceKm = vehicle.current.distance(newWaypoint)
                    if (distanceKm > 50)
                        Vehicle.log.warn(
                            "Jump too far: {} from {} to {}, by {} km. \nCurrent route: {}\nAssigned route: {}",
                            plate,
                            vehicle.current,
                            newWaypoint,
                            distanceKm,
                            currentRoute,
                            assignedRoute
                        )
                    vehicle = vehicle.setWaypoint(newWaypoint)
                    currentRoute = currentRoute.drop(1)
                    vertx.eventBus().publish(FleetEvent.VehicleUpdated, vehicle.toJson())
                    VehicleSimCounters.vehicleUpdates.inc()
                }
            } else {
                waitCycles--
            }
        }
    }

    private val plateReturned = AtomicBoolean(false)

    private fun returnPlateOnce() {
        if(plateReturned.compareAndSet(false, true)) {
            log.debug("Returning plate ${vehicle.plate} from vehicle ${deploymentID}")
            PlateIssuer.default.returnPlate(vehicle.plate)
        } else {
            log.debug("Plate ${vehicle.plate} already returned from ${deploymentID}")
        }
    }

    override suspend fun stop() {
        log.debug("vehicle ${plate} ${deploymentID} stop")
        super.stop()
//        PlateIssuer.default.returnPlate(vehicle.plate)
        returnPlateOnce()
        VehicleSimCounters.vehiclesRemoved.inc()
        VehicleSimCounters.vehiclesCurrent.dec()
        mqttConnect.disconnectMqtt()
        if (!undeployRequested) {
            VehicleSimCounters.vehiclesUnsolicitedRemovals.inc()
            log.warn("Vehicle $plate $deploymentID stopped without undeployVerticle")
        }
    }

    private suspend fun undeployVerticle() {
        log.debug("vehicle ${plate} undeployVerticle")
        returnPlateOnce()
        VehicleSimCounters.vehiclesUndeployRequested.inc()
        vertx.undeploy(this.deploymentID)
        vertx.eventBus().publish(FleetEvent.VehicleRemoved, vehicle.toJson())
        publishVehicleRemoveToMqtt()
        undeployRequested = true
    }

    private suspend fun publishVehicleUpdateToMqtt() {
        val body = Buffer.buffer(vehicle.toJson().toString())
        mqttConnect.getConnectedMqttClient().publish(
            "${topicPrefix}vehicle_updates/${vehicle.plate}",
            body,
            MqttQoS.AT_MOST_ONCE,
            false,
            false
        )
        VehicleSimCounters.mqttMessagesSent.inc()

        if(vehicle.visible) {
            mqttConnect.getConnectedMqttClient().publish(
                "${topicPrefix}visible_vehicle_updates/${vehicle.plate}",
                body,
                MqttQoS.AT_MOST_ONCE,
                false,
                false
            )
            VehicleSimCounters.mqttMessagesSent.inc()
        }
    }

    private suspend fun publishVehicleRemoveToMqtt() {
        mqttConnect.getConnectedMqttClient().publish(
            "${topicPrefix}vehicle_updates/${vehicle.plate}",
            Buffer.buffer(),
            MqttQoS.AT_MOST_ONCE,
            false,
            false
        )
        VehicleSimCounters.mqttMessagesSent.inc()

        if(vehicle.visible) {
            mqttConnect.getConnectedMqttClient().publish(
                "${topicPrefix}visible_vehicle_updates/${vehicle.plate}",
                Buffer.buffer(),
                MqttQoS.AT_MOST_ONCE,
                false,
                false
            )
            VehicleSimCounters.mqttMessagesSent.inc()
        }
    }

    private suspend fun publishCompanyPassengersUpdateToMqtt() {
        val mqttTopic = "${topicPrefix}passengers_update/${vehicle.companyName}"
        val companyPassengersJson = CompanyPassengers(
            vehicle.companyName,
            (vehicle.passengers * if (vehicle.isHired) 1 else -1),
            mqttTopic
        ).toJson()

        val body = Buffer.buffer(companyPassengersJson.toString())
        mqttConnect.getConnectedMqttClient().publish(
            mqttTopic,
            body,
            MqttQoS.AT_MOST_ONCE,
            false,
            false
        )
    }
}
