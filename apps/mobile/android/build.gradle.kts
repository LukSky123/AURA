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

subprojects {
    if (project.name != "app") {
        val configureAndroid = {
            val android = project.extensions.findByName("android")
            if (android != null) {
                val methods = android.javaClass.methods
                val compileSdkMethod = methods.find {
                    it.name == "compileSdkVersion" &&
                    it.parameterTypes.size == 1 &&
                    (it.parameterTypes[0] == Int::class.javaPrimitiveType || it.parameterTypes[0] == java.lang.Integer::class.java)
                }
                if (compileSdkMethod != null) {
                    compileSdkMethod.invoke(android, 36)
                    println("Forced ${project.name} compileSdkVersion to 36")
                } else {
                    val setCompileSdk = methods.find {
                        it.name == "setCompileSdk" && it.parameterTypes.size == 1
                    }
                    setCompileSdk?.invoke(android, 36)
                    println("Forced ${project.name} setCompileSdk to 36")
                }
            }
        }

        if (project.state.executed) {
            configureAndroid()
        } else {
            project.afterEvaluate {
                configureAndroid()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
