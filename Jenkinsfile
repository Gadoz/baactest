pipeline {
    parameters { 
        choice( name: 'DEPLOY_ENV', choices: ['DEV', 'SIT' , 'UAT'], description: 'Deploy to environment?')
    }

    agent {
        dockerfile {
            filename 'Dockerfile'
            dir 'GoBuildSystem'
            additionalBuildArgs  '--build-arg version=latest'
            args '-v /var/lib/jenkins/tools/hudson.plugins.sonar.SonarRunnerInstallation:/var/lib/jenkins/tools/hudson.plugins.sonar.SonarRunnerInstallation \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "\$PWD":/usr/src/myapp \
            -w /usr/src/myapp \
            -e JFROG_CLI_OFFER_CONFIG=false'
        }
    }

    stages {
         stage('Initial Environment'){
			steps {
                script {
                    def prop = readProperties  file:'.env'
                    // prop.each{ k,v -> println "$k = $v" }
                    prop.each{ k,v -> env."${k}" = "${v}" }
					MESSAGE_TEMPLATE = "$JOB_NAME Build #$BUILD_ID " + env['MESSAGE_TEMPLATE'] + "\r\n ${BUILD_URL}input"
					DEV_HOST = "${KUBE_DEV_HOST}" + "." + "${KUBE_DEV_ZONE}"
                    SIT_HOST = "${KUBE_SIT_HOST}" + "." + "${KUBE_SIT_ZONE}"
                    UAT_HOST = "${KUBE_UAT_HOST}" + "." + "${KUBE_UAT_ZONE}"
                    PROD_HOST = "${KUBE_PROD_HOST}" + "." + "${KUBE_PROD_ZONE}"

                    DEV_BRANCH_HOST = "${KUBE_DEV_BRANCH_HOST}" + "." + "${KUBE_DEV_BRANCH_ZONE}"
                    SIT_BRANCH_HOST = "${KUBE_SIT_BRANCH_HOST}" + "." + "${KUBE_SIT_BRANCH_ZONE}"
                    UAT_BRANCH_HOST = "${KUBE_UAT_BRANCH_HOST}" + "." + "${KUBE_UAT_BRANCH_ZONE}"
                    
                    IMAGE_VERSION = "" // "${BUILD_ID}"
                    
                    withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'jfrog-credentials', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD']]) {
                        def SPLIT_URL = "${JFROG_ARTIFACTORY_URL}".split('://')
                        env.GOPROXY = SPLIT_URL[0] + "://$USERNAME:$PASSWORD@" + SPLIT_URL[1] + "/api/go/${JFROG_VIRTUAL_REPO}"
                        echo "${GOPROXY}"
                    }
                    
                    if (env.GIT_BRANCH != "${BRANCH_MASTER_NAME}") {
                        branchName = env.GIT_BRANCH.replace("origin/","") // Remove Branch name prefix 
                        IMAGE_VERSION = "-${branchName}" // ${branchName}-$BUILD_ID
                    }
                    
                    echo "${IMAGE_VERSION}"
                    
                    withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: JFROG_CREDENTIALS, usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD']]) {
                        sh "jfrog rt config --url=${JFROG_ARTIFACTORY_URL} --user=$USERNAME --password=$PASSWORD"
                    }

                    // Child Branch Decision
                    env.BRANCH_ENV = 1 // Default Environment : DEV
                    env.DO_SIT = false
                    env.DO_UAT = false
                    env.DO_PROD = false

                    if(env.GIT_BRANCH != "${BRANCH_MASTER_NAME}"){
                        // Developer branch
                        if(params.DEPLOY_ENV == "DEV"){ 
                            env.BRANCH_ENV = 1 // DEV 
                        }
                        else if(params.DEPLOY_ENV == "SIT"){ 
                            env.BRANCH_ENV = 2 // DEV SIT 
                            env.DO_SIT = true
                        }
                        else{ 
                            env.BRANCH_ENV = 3 // DEV SIT UAT 
                            env.DO_SIT = true
                            env.DO_UAT = true
                        }
                    }else{
                        // Master branch Enable all stages
                        env.DO_SIT = true
                        env.DO_UAT = true
                        env.DO_PROD = true
                    }


                }                
            }
		}
        
        stage('Test') {
            steps {
                sh "go test ./service -v"
                sh "ls -lt"
            }
        }
                
        stage('Build') {
            steps {
                sh "go build -v"
                sh "ls -lt"
            }
        }

        stage('Push to Artifact') {
            steps {
          
                sh "mkdir build \
                && cp ${PROJECT_NAME} ./build/ \
                && cp go.mod ./build/ \
                && cp -R conf ./build/ "
                
                dir("./build")  {
                    sh "ls -lt"
                    sh "jfrog rt go-publish ${JFROG_LOCAL_REPO} v${PROJECT_VERSION}${IMAGE_VERSION} --insecure-tls=true"
                }
            }
        }

        stage('Create Image') {
            steps {
                
                sh "mkdir -p dockerfile-workspace"
                sh "cp Dockerfile ./dockerfile-workspace"
                dir("./dockerfile-workspace"){
                    sh "jfrog rt dl ${JFROG_LOCAL_REPO}/${PROJECT_NAME}/@v/v${PROJECT_VERSION}${IMAGE_VERSION}.zip"
    
                    sh "mv ./${PROJECT_NAME}/@v/v${PROJECT_VERSION}${IMAGE_VERSION}.zip ."
                    sh "rm -rf ${PROJECT_NAME}"
                    sh "unzip v${PROJECT_VERSION}${IMAGE_VERSION}.zip"   
                    sh "mv ${PROJECT_NAME}\\@v${PROJECT_VERSION}${IMAGE_VERSION}/* ."
                    sh "rm -f v${PROJECT_VERSION}${IMAGE_VERSION}.zip"
                    sh "rm -rf ${PROJECT_NAME}@v${PROJECT_VERSION}${IMAGE_VERSION}"
                    sh "ls -laish"                 
                    script{
                        docker.withRegistry(DOCKER_REGISTRY_PROTOCAL + DOCKER_REGISTRY_URL, DOCKER_REGISTRY_CREDENTIALS) {
                            docker.build("${DOCKER_REGISTRY_BASE}/${PROJECT_NAME}:${PROJECT_VERSION}${IMAGE_VERSION}").push()
                        }      
                        sh "docker rmi ${DOCKER_REGISTRY_BASE}/${PROJECT_NAME}:${PROJECT_VERSION}${IMAGE_VERSION}"
                        sh "docker rmi ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_BASE}/${PROJECT_NAME}:${PROJECT_VERSION}${IMAGE_VERSION}"              
                    }
                 }
            }
        }
        
        stage('Deploy to Kubernetes (DEV)') {
            steps{
                script{
                    if(env.GIT_BRANCH != "${BRANCH_MASTER_NAME}" && BRANCH_ENV.toInteger() >= 1){
                        // Child Branch
                        initialKubeFile("${KUBE_DEV_FILE}","${KUBE_DEV_BRANCH_NAMESPACE}","${KUBE_DEV_BRANCH_SECRET}","${DEV_BRANCH_HOST}")
                        deployToKubernetes("${KUBE_DEV_FILE}","${KUBECONFIG_DEV}")
                        dnsUpdate("${KUBE_DEV_BRANCH_HOST}","${KUBE_DEV_BRANCH_ZONE}","${KUBE_IP}")
                    }else{
                        // Master
                        initialKubeFile("${KUBE_DEV_FILE}","${KUBE_DEV_NAMESPACE}","${KUBE_DEV_SECRET}","${DEV_HOST}")
                        deployToKubernetes("${KUBE_DEV_FILE}","${KUBECONFIG_DEV}")  
                        dnsUpdate("${KUBE_DEV_HOST}","${KUBE_DEV_ZONE}","${KUBE_IP}")
                    }
                }
            }
        }

        stage('Robot Selenium Test (DEV)') {
            steps {
                script{
                     if(env.GIT_BRANCH != "${BRANCH_MASTER_NAME}" && BRANCH_ENV.toInteger() >= 1){
                        // Child Branch
                        initialRobotFile("${ROBOT_DEV_FILE}","${DEV_BRANCH_HOST}")
					 	robotTest("${ROBOT_DEV_FILE}","DEV-${branchName}")
                     }else{
                        // Master
                        initialRobotFile("${ROBOT_DEV_FILE}","${DEV_HOST}")
						robotTest("${ROBOT_DEV_FILE}",'DEV') 
                     }
                }
            }
        }

        stage('JMeter Test (DEV)') {
            steps {
                script{
                    if(env.GIT_BRANCH != "${BRANCH_MASTER_NAME}" && BRANCH_ENV.toInteger() >= 1){
                        // Child Branch
                        initialJMeterFile("${JMETER_DEV_FILE}","${DEV_BRANCH_HOST}")
					 	jmeterTest("${JMETER_DEV_FILE}","DEV-${branchName}")
                    }else{
                        // Master
					 	initialJMeterFile("${JMETER_DEV_FILE}","${DEV_HOST}")
						jmeterTest("${JMETER_DEV_FILE}",'DEV') // master branch
                    }
                }
            }
        }
		
        stage('Code Analysis') {
            steps{
                script{
                    def scannerHome = tool 'sonarQScannerlocal';
                    withSonarQubeEnv('sonarQlocal') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
                }
            }                            
        }
        
        stage("Quality Gate") {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: true
                }
            }
            post {
                success{
                    echo "Sonar success"
                    script{
                        rocket("developer","${BUILD_URL} SonarQube : Build Succeeded")
                        rocket("it_admin","${BUILD_URL} SonarQube : Build Succeeded")
                    }
                }
                failure{
                    echo "Sonar failed"
                    script{
                        rocket("developer","${BUILD_URL} SonarQube : Build Failed")
                        rocket("it_admin","${BUILD_URL} SonarQube : Build Failed")
                    }
                }
            }
        }

        stage('Deploy to Kubernetes (SIT)') {
             when {  expression { return env.DO_SIT.toBoolean() == true; } }
             steps{
				script{
				
					if(env.GIT_BRANCH != "${BRANCH_MASTER_NAME}" && BRANCH_ENV.toInteger() >= 2){
						initialKubeFile("${KUBE_SIT_FILE}","${KUBE_SIT_BRANCH_NAMESPACE}","${KUBE_SIT_BRANCH_SECRET}","${SIT_BRANCH_HOST}")
						deployToKubernetes("${KUBE_SIT_FILE}","${KUBECONFIG_SIT}")
						dnsUpdate("${KUBE_SIT_BRANCH_HOST}","${KUBE_SIT_BRANCH_ZONE}","${KUBE_IP}")
					}
					else{
						initialKubeFile("${KUBE_SIT_FILE}","${KUBE_SIT_NAMESPACE}","${KUBE_SIT_SECRET}","${SIT_HOST}")
						deployToKubernetes("${KUBE_SIT_FILE}","${KUBECONFIG_SIT}")
						dnsUpdate("${KUBE_SIT_HOST}","${KUBE_SIT_ZONE}","${KUBE_IP}")
					}
                }
             }
         }

         stage('Robot Selenium Test (SIT)') {
             when {  expression { return env.DO_SIT.toBoolean() == true; } }
             steps {
				script{
					if(env.GIT_BRANCH != "${BRANCH_MASTER_NAME}" && BRANCH_ENV.toInteger() >= 2){
						initialRobotFile("${ROBOT_SIT_FILE}","${SIT_BRANCH_HOST}")
						robotTest("${ROBOT_SIT_FILE}","SIT-${branchName}")
					}
					else{
						initialRobotFile("${ROBOT_SIT_FILE}","${SIT_HOST}")
						robotTest("${ROBOT_SIT_FILE}",'SIT')
					}
				}
             }
         }

         stage('JMeter Test (SIT)') {
             when {  expression { return env.DO_SIT.toBoolean() == true; } }
             steps {
				script{
					if(env.GIT_BRANCH != "${BRANCH_MASTER_NAME}" && BRANCH_ENV.toInteger() >= 2){
						initialJMeterFile("${JMETER_SIT_FILE}","${SIT_BRANCH_HOST}")
						jmeterTest("${JMETER_SIT_FILE}","SIT-${branchName}") // master branch
					}
					else{
						initialJMeterFile("${JMETER_SIT_FILE}","${SIT_HOST}")
						jmeterTest("${JMETER_SIT_FILE}",'SIT') // master branch
					}
				}
             }
         }

        stage('Aprrove for UAT') {
            when { 
                allOf {
                    expression { return env.GIT_BRANCH != "${BRANCH_MASTER_NAME}" }
                    expression { return env.DO_UAT.toBoolean() == true; }
                } 
            }  
            parallel {
                stage('First Approve') {
                    steps {
                        echo "${MESSAGE_TEMPLATE}"
                        notifyEmail('Approve for UAT 1!',"${MESSAGE_TEMPLATE}","${APPROVE_1}")
                        timeout(time: 3, unit: "DAYS"){
                            input id: 'Approve1', message: "Deploy to UAT?, Approval by ${APPROVE_1}", ok: "Approve" ,submitter: "${APPROVE_1}"
                        }
                    }
                }

                stage('Second Approve') {
                    steps {
                        notifyEmail('Approve for UAT 2!',"${MESSAGE_TEMPLATE}","${APPROVE_2}")
                        timeout(time: 3, unit: "DAYS"){
                            input id: 'Approve2', message: "Deploy to UAT?, Approval by ${APPROVE_2}", ok: "Approve" ,submitter: "${APPROVE_2}"
                        }
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes (UAT)') {
            when {  expression { return env.DO_UAT.toBoolean() == true; } }
            steps{
				script{
					if(env.GIT_BRANCH != "${BRANCH_MASTER_NAME}" && BRANCH_ENV.toInteger() >= 3){
						initialKubeFile("${KUBE_UAT_FILE}","${KUBE_UAT_BRANCH_NAMESPACE}","${KUBE_UAT_BRANCH_SECRET}","${UAT_BRANCH_HOST}")
						deployToKubernetes("${KUBE_UAT_FILE}","${KUBECONFIG_UAT}")
						dnsUpdate("${KUBE_UAT_BRANCH_HOST}","${KUBE_UAT_BRANCH_ZONE}","${KUBE_IP}")
					}
					else{
						initialKubeFile("${KUBE_UAT_FILE}","${KUBE_UAT_NAMESPACE}","${KUBE_UAT_SECRET}","${UAT_HOST}")
						deployToKubernetes("${KUBE_UAT_FILE}","${KUBECONFIG_UAT}")
						dnsUpdate("${KUBE_UAT_HOST}","${KUBE_UAT_ZONE}","${KUBE_IP}")
					}
				}
            }
        }

        stage('Robot Selenium Test (UAT)') {
            when {  expression { return env.DO_UAT.toBoolean() == true; } }
            steps {
				script{
					if(env.GIT_BRANCH != "${BRANCH_MASTER_NAME}" && BRANCH_ENV.toInteger() >= 3){
						initialRobotFile("${ROBOT_UAT_FILE}","${UAT_BRANCH_HOST}")
						robotTest("${ROBOT_UAT_FILE}","UAT-${branchName}")  // master branch
					}
					else{
						initialRobotFile("${ROBOT_UAT_FILE}","${UAT_HOST}")
						robotTest("${ROBOT_UAT_FILE}",'UAT')  // master branch
					}
				}
            }
        }

        stage('JMeter Test (UAT)') {
            when {  expression { return env.DO_UAT.toBoolean() == true; } }
            steps {
				script{
					if(env.GIT_BRANCH != "${BRANCH_MASTER_NAME}" && BRANCH_ENV.toInteger() >= 3){
						initialJMeterFile("${JMETER_UAT_FILE}","${UAT_BRANCH_HOST}")
						jmeterTest("${JMETER_UAT_FILE}","UAT-${branchName}") // master branch
					}
					else{
						initialJMeterFile("${JMETER_UAT_FILE}","${UAT_HOST}")
						jmeterTest("${JMETER_UAT_FILE}",'UAT') // master branch
					}
				}
            }
        }
        
        stage('Aprrove for production') {
            when {  expression { return env.DO_PROD.toBoolean() == true; } }
            parallel {
                stage('First Approve') {
                    steps {
                        echo "${MESSAGE_TEMPLATE}"
                        notifyEmail('Approve for production 1!',"${MESSAGE_TEMPLATE}","${APPROVE_1}")
                        timeout(time: 3, unit: "DAYS"){
                            input id: 'Approve1', message: "Deploy to production?, Approval by ${APPROVE_1}", ok: "Approve" ,submitter: "${APPROVE_1}"
                        }
                    }
                }

                stage('Second Approve') {
                    steps {
                        notifyEmail('Approve for production 2!',"${MESSAGE_TEMPLATE}","${APPROVE_2}")
                        timeout(time: 3, unit: "DAYS"){
                            input id: 'Approve2', message: "Deploy to production?, Approval by ${APPROVE_2}", ok: "Approve" ,submitter: "${APPROVE_2}"
                        }
                    }
                }
            }
        }

        stage('Deploy to Kubernetes (PROD)') {
            when {  expression { return env.DO_PROD.toBoolean() == true; } }
            steps{
                initialKubeFile("${KUBE_PROD_FILE}","${KUBE_PROD_NAMESPACE}","${KUBE_PROD_SECRET}","${PROD_HOST}")
				deployToKubernetes("${KUBE_PROD_FILE}","${KUBECONFIG_PROD}")
				dnsUpdate("${KUBE_PROD_HOST}","${KUBE_PROD_ZONE}","${KUBE_IP}")
            }
        }
    }

    post { 
        always {
            script {
                step(
                    [
                        $class              : 'RobotPublisher',
                        outputPath          : 'robot-result',
                        outputFileName      : "**/output.xml",
                        reportFileName      : '**/report.html',
                        logFileName         : '**/log.html',
                        disableArchiveOutput: false,
                        passThreshold       : 100,
                        unstableThreshold   : 95,
                        otherFiles          : "**/*.png,**/*.jpg",
                    ]
                )
            }
            deleteDir()
        }
        success{
            echo "Post all stage success"
            script{
                rocket("developer","${BUILD_URL} Pipeline : Build Succeeded")
		        rocket("it_admin","${BUILD_URL} Pipeline : Build Succeeded")
            }
        }
        failure{
            echo "Post all stage failed"
            script{
                rocket("developer","${BUILD_URL} Pipeline : Build Failed")
		        rocket("it_admin","${BUILD_URL} Pipeline : Build Failed")
            }
        }
    }
}

def initialKubeFile(fileName,namespace,secret,host){
	script{
		dir("./kubernetes-deployment"){
            sh "ls -lt"
            sh "cat ${fileName}"
			image = "${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_BASE}/${PROJECT_NAME}:${PROJECT_VERSION}${IMAGE_VERSION}" // :${IMAGE_VERSION}
			
			def kube = readFile("${fileName}")
			kube = kube.replace("{KUBE_NAMESPACE}", "${namespace}");
			kube = kube.replace("{KUBE_IMAGE}", "${image}")
			kube = kube.replace("{KUBE_SECRET}", "${secret}");
			kube = kube.replace("{KUBE_INGRESS_HOST}", "${host}");
			writeFile file:"${fileName}", text:kube
            sh "cat ${fileName}"
		}
	}
}

def initialJMeterFile(fileName,host){
	script{
		dir("./jmeter-test"){
			def jmeter = readFile("${fileName}")
			jmeter = jmeter.replace("{JMETER_HOST}", "${host}")
			writeFile file:"${fileName}", text:jmeter
		}
	}
}

def initialRobotFile(fileName,host){
	script{
		dir("./robot-test"){
			def robot = readFile("${fileName}")
			robot = robot.replace("{ROBOT_HOST}", "http://" + "${host}")
			writeFile file:"${fileName}", text:robot
            sh "cat ${fileName}"
		}
	}
}

def rocket(channel,message){
    rocketSend channel: "${channel}", message: "${message}", rawMessage: true, serverUrl: "${ROCKET_URL}", trustSSL: true, webhookToken: "${ROCKET_TOKEN}"
}

def notifyEmail(subject,msg,to) {
    emailext body: "${msg}", subject: "${subject}", to: "${to}"
}

def deployToKubernetes(deployment,credential){
    echo "${credential}"
    script{
        withCredentials([file(credentialsId: "${credential}", variable: 'config')]) {   
            sh "mv \$config ${KUBECONFIG}"
        }

        dir("./kubernetes-deployment"){
            sh "kubectl delete -f ${deployment} || true"  
            sh "kubectl apply -f ${deployment} --validate=false"
        }
        // Get Kube IP
        getKubeIP("${credential}")
    }
}

def getKubeIP(credential){
    script {
        withCredentials([file(credentialsId: "${credential}", variable: 'config')]) { 
            sh "kubectl --kubeconfig=\$config get nodes -o wide | grep master | grep -o '[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}' > kube-ip.txt"
        }
        def ip = readFile 'kube-ip.txt'
        KUBE_IP = ip.toString()
        sh "rm -f kube-ip.txt"
	    echo "${KUBE_IP}"
    }
}

def dnsUpdate(host,zone,ip){
    echo "${host} ${zone} ${ip}"
    build job: "${DNS_PIPELINE}",  
          parameters: [ string(name: 'HOST_NAME', value: "${host}" ), 
                        string(name: 'HOST_ZONE', value: "${zone}" ), 
                        string(name: 'HOST_IP', value: "${ip}" )
                    ], wait: true
}

def robotTest(file,outputFolder){
    sh "mkdir -p robot-result/${outputFolder}" // Make Directory wait for result
    echo "${file}"
    echo "${outputFolder}"	    
    build job: "${ROBOT_PIPELINE}",  
          parameters: [ string(name: 'FROM_JOB_NAME', value: "$JOB_NAME" ), 
                        string(name: 'RUN_FILE', value: "${file}" ), 
                        string(name: 'RESULT_FOLDER', value: "${outputFolder}" )
                    ], wait: true
    dir("./robot-result/${outputFolder}"){
        sh 'ls'
    }
}

def jmeterTest(file,outputFolder){
    sh "mkdir -p jmeter-result/${outputFolder}" // Make Directory wait for result
    build job: "${JMETER_PIPELINE}",  
          parameters: [ string(name: 'FROM_JOB_NAME', value: "$JOB_NAME" ), 
                        string(name: 'RUN_FILE', value: "${file}" ), 
                        string(name: 'RESULT_FOLDER', value: "${outputFolder}" )
                    ], wait: true
    dir("./jmeter-result/${outputFolder}"){
        sh 'ls'
        // Publish JMeter Report
        perfReport "jmeterResultTest-${outputFolder}.csv"
    }
}


