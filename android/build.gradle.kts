import java.io.File

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

val tempRoot = System.getenv("TEMP") ?: "C:/Temp"

subprojects {
    if (project.name == "app") {
        val appBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(appBuildDir)
    } else {
        val subprojectTempDir = File(tempRoot, "wunderbarai-gradle-subprojects/${project.name}")
        val subprojectDirProvider = project.providers.provider { subprojectTempDir }
        project.layout.buildDirectory.set(project.layout.dir(subprojectDirProvider))
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
