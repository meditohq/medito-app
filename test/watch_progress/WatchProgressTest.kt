package meditofoundation.medito.wear

import org.json.JSONArray
import java.io.File
import java.util.TimeZone

fun main(args: Array<String>) {
    TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
    val fixtures = JSONArray(File(args[0]).readText())
    for (i in 0 until fixtures.length()) {
        val fixture = fixtures.getJSONObject(i)
        val outbox = fixture.getJSONArray("pending")
        val result = WatchProgress.project(fixture.getJSONObject("snapshot"),
            (0 until outbox.length()).map { outbox.getJSONObject(it) }, fixture.getLong("now"))
        val pack = result.getJSONObject("upNext")
        val expected = fixture.getJSONObject("expected")
        for (key in listOf("completed", "id", "canPlay")) {
            check(pack.get(key).toString() == expected.get(key).toString()) { "${fixture.getString("name")}: $key" }
        }
        check(result.getInt("streak") == expected.getInt("streak")) { "${fixture.getString("name")}: streak" }
        if (expected.has("consistency")) {
            check(result.getInt("consistency") == expected.getInt("consistency")) {
                "${fixture.getString("name")}: consistency"
            }
        }
    }
    println("Kotlin: ${fixtures.length()} watch progress cases passed")
}
