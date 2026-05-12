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

// AGP 8+ requires plugin libraries to use `namespace` instead of the old
// AndroidManifest.xml `package` attribute. isar_flutter_libs 3.1.0+1 still
// ships the old manifest, so patch it when Gradle builds the hosted package.
subprojects {
    if (name == "isar_flutter_libs") {
        val patchIsarManifest = tasks.register("patchIsarFlutterLibsManifest") {
            doLast {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val original = manifestFile.readText()
                    val patched = original.replace(
                        Regex("\\s+package=\"dev\\.isar\\.isar_flutter_libs\""),
                        "",
                    )
                    if (patched != original) {
                        manifestFile.writeText(patched)
                    }
                }
            }
        }

        tasks.matching { it.name.startsWith("process") && it.name.endsWith("Manifest") }
            .configureEach {
                dependsOn(patchIsarManifest)
            }
    }
}

// AGP 8+ also requires `namespace` in all Android modules.
subprojects {
    plugins.withId("com.android.library") {
        extensions.findByName("android")?.let { androidExt ->
            try {
                val getNs = androidExt.javaClass.getMethod("getNamespace")
                val ns = getNs.invoke(androidExt) as? String
                if (ns == null || ns.isEmpty()) {
                    val setNs = androidExt.javaClass.methods.firstOrNull { it.name == "setNamespace" && it.parameterTypes.size == 1 }
                    val fallbackNamespace =
                        if (project.name == "isar_flutter_libs") {
                            "dev.isar.isar_flutter_libs"
                        } else {
                            "com.example.${project.name.replace(Regex("[^A-Za-z0-9_]"), "_")}"
                        }
                    setNs?.invoke(androidExt, fallbackNamespace)
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
