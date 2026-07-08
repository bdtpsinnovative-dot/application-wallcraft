import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // ให้แน่ใจว่า :app ถูก evaluate ก่อน
    project.evaluationDependsOn(":app")

    // แก้ไขปัญหาคอมไพล์ซ้ำ (Conflicting declarations) ของปลั๊กอิน speech_to_text บน Kotlin 2.x
    if (project.name == "speech_to_text") {
        project.plugins.withId("com.android.library") {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.sourceSets?.configureEach {
                if (name == "main") {
                    val filteredDirs = java.srcDirs.filter { !it.absolutePath.replace("\\", "/").endsWith("src/main/kotlin") }
                    java.setSrcDirs(filteredDirs)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
