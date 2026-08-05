package meditofoundation.medito.widget

import org.junit.Test
import java.io.File

class PwdCheckTest {
    @Test
    fun printCwd() {
        println("CWD=" + File(".").absolutePath)
    }
}
