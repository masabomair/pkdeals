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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// The release "lint vital" check crashes inside Android lint itself when it
// scans the Firebase plugins (NoSuchMethodError in JavaDocParser). It only
// reports warnings, so skip it; the app is still compiled and checked normally.
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
