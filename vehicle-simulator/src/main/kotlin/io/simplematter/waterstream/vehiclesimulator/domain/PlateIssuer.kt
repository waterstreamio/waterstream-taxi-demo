package io.simplematter.waterstream.vehiclesimulator.domain

import java.lang.RuntimeException
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.ConcurrentSkipListSet
import kotlin.random.Random
import org.slf4j.LoggerFactory

class PlateIssuer(seed: Long) {
    private val log = LoggerFactory.getLogger(PlateIssuer::class.java)

    private val generatedPlates = ConcurrentSkipListSet<String>()
    private val returnedPlates = ConcurrentLinkedQueue<String>()

    private val rng = Random(seed)

    tailrec private fun generatePlate(remainingAttempts: Int): String {
        val begin: String = listOf(1).map { IntRange(0, 9).random(rng) }.joinToString("")
        val middle: String = listOf(1).map { CharRange('A', 'Z').random(rng) }.joinToString("")
        val end: String = listOf(1, 2).map { IntRange(0, 9).random(rng) }.joinToString("")

        val plate = "$begin$middle$end"

        return when {
            generatedPlates.add(plate) -> plate
            remainingAttempts > 0 -> generatePlate(remainingAttempts - 1)
            else -> throw RuntimeException("Unable to generate a plate. Last attempt: ${plate}, existing plates count: ${generatedPlates.size}")
        }
    }

    fun issuePlate(): String {
        val plateFromReturned = returnedPlates.poll()
        if (plateFromReturned == null) {
            val newPlate = generatePlate(1000)
            log.debug("Issued newly generated plate {}", newPlate)
            return newPlate
        } else {
            log.debug("Issued reused plate {}", plateFromReturned)
            return plateFromReturned
        }
    }

    fun returnPlate(plate: String) {
        returnedPlates.add(plate)
        log.info("Plate {} returned", plate)
    }

    companion object {
        val default = PlateIssuer(20200331)
    }
}
