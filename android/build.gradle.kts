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

// AGP 8+ requires `namespace` in ALL Android modules (including library modules from plugins).
// Some plugin libraries (e.g. isar_flutter_libs) may not provide it.
subprojects {
    plugins.withId("com.android.library") {
        extensions.findByName("android")?.let { androidExt ->
            val nsProp = androidExt.javaClass.methods.find { it.name == "getNamespace" }
            // If namespace getter exists but returns null/empty, we set a fallback.
            try {
                val getNs = androidExt.javaClass.getMethod("getNamespace")
                val ns = getNs.invoke(androidExt) as? String
                if (ns == null || ns.isEmpty()) {
                    val setNs = androidExt.javaClass.methods.firstOrNull { it.name == "setNamespace" && it.parameterTypes.size == 1 }
                    setNs?.invoke(androidExt, "com.example.${project.name}")
                }
            } catch (_: Throwable) {
                // Best-effort; if reflection fails, Gradle will still show original error.
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
