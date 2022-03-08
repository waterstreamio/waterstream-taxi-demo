package io.simplematter.waterstream.vehiclesimulator.domain

import io.vertx.core.json.JsonArray
import io.vertx.core.json.JsonObject
import io.vertx.kotlin.core.json.get
import kotlin.random.Random
import java.io.File

object CoordinateGenerator {

  private var coords: MutableList<Point>

  init {
    val coordinateCsvText = object {}.javaClass.getResource("/nyc_points_of_interest.csv").readText()
    coords = ArrayList<Point>()
    
    val maxLatitude = 40.873014 // coordinate limit around Manhattan island in NYC
    val minLatitude = 40.696747
    val minLongitude = -74.025571
    val maxLongitude = -73.907346    

    for (line in coordinateCsvText.lines())
    {
      val firstOpenBracketIndex = line.indexOf("(")

      if (firstOpenBracketIndex != -1) {
        val coordText = line.substring(firstOpenBracketIndex + 1, line.indexOf(")"))
        val coordTextArray = coordText.split(" ")

        val latitude = coordTextArray[1].toDouble()
        val longitude = coordTextArray[0].toDouble()
        if(minLatitude < latitude && latitude < maxLatitude && minLongitude < longitude && longitude < maxLongitude) {
          coords.add(Point(latitude, longitude))
        }
      }
    }

  }

  fun nextPoint(): Point {
    return coords.get(
        Random.nextInt(
          coords.size
        )
      )
  }
}
