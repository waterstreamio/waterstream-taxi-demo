package io.simplematter.waterstream.vehiclesimulator.domain

import io.vertx.core.json.JsonObject

data class CompanyPassengers(
    val company: String,
    val passengers: Int,
    val topic: String
)

fun CompanyPassengers.toJson(): JsonObject {
    val json = JsonObject()
    json.put("company", company)
    json.put("passengers", passengers)
    json.put("topic", topic)
    return json
}