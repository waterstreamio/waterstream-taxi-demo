package io.simplematter.waterstream

import com.typesafe.config.ConfigFactory
import io.github.config4k.extract


data class VehicleSimulatorUiConfig(
    val messageCountPanelAddress: String,
    val messageCountPanelLink: String,
    val taxisStatsPanelAddress: String,
    val mqttHost: String,
    val mqttPort: String,
    val mqttUseSsl: String,
    val mqttClientPrefix: String,
    val mqttVisibleVehiclesTopicPrefix: String
) {
    companion object {
        fun load(): VehicleSimulatorUiConfig {
            val config = ConfigFactory.load()
            return config.extract<VehicleSimulatorUiConfig>()
        }
    }
}