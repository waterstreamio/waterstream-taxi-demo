package io.simplematter.waterstream.vehiclesimulator.tools

import com.github.kittinunf.fuel.Fuel
import com.github.kittinunf.fuel.core.Request
import com.github.kittinunf.fuel.core.Response
import com.github.kittinunf.fuel.coroutines.awaitStringResponse
import com.google.gson.JsonParser
import io.simplematter.waterstream.vehiclesimulator.domain.*
import io.simplematter.waterstream.vehiclesimulator.monitoring.VehicleSimCounters


class RouteGenerator(private var routingUrl: String) {

    private suspend fun getRouteFromService(start: Point, end: Point): List<Point> {

        val parameters = listOf(
            "profile" to "driving-car", // TODO change sw logic to taxi, replace in UI as well
            "coordinates" to "${start.toQueryParam()}|${end.toQueryParam()}",
            "geometry_format" to "geojson"
        )

        // lateinit var request: Request
        try {
            val (request: Request, _: Response, result: String) = Fuel.get(
                routingUrl,
                parameters
            ).awaitStringResponse(Charsets.UTF_8)
            VehicleSimCounters.routeRequests.inc()
            //println("getRouteFromService request: ${request.cUrlString()}\nand result: ${result}}")

            val routes = JsonParser.parseString(result).asJsonObject.getAsJsonArray("routes")
            val coordinates = routes[0].asJsonObject.getAsJsonObject("geometry").getAsJsonArray("coordinates")
            val route = coordinates.map { it ->
                Point(it.asJsonArray[1].asDouble, it.asJsonArray[0].asDouble)
            }
            return route
        } catch (e: Exception) {
            // println("getRouteFromService throws ${e}")
            return listOf()
        }
    }

    suspend fun generateRoute(): List<Point> {
        var candidate = listOf<Point>()
        while (candidate.isEmpty()) {
            val startingPoint = CoordinateGenerator.nextPoint()
            candidate = nextRoute(startingPoint)
        }
        return candidate
    }

    private suspend fun nextRoute(startingPoint: Point): List<Point> {
        val candidate = getRouteFromService(startingPoint, CoordinateGenerator.nextPoint())
        return if (candidate.size < 2) {
            listOf()
        } else {
            candidate
        }
    }
}