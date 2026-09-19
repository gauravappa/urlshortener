@Library("jenkins-shared-lib") _
pipeline {
    agent {label "ec2-agent"}
    stages{
        stage("Start"){
            steps{
                echo "Starting Pipeline"
            }
        }
        stage("Code"){
            steps{
                echo "Start Cloning Repo"
                script{
                    clone("https://github.com/gauravappa/urlshortener.git","master")
                }
                echo "Cloning Successfull"
            }
        }
        stage("Build Docker Image"){
            steps{
                echo "Building Docker Image"
                buildImage("url-shortener-svc","latest")
                echo "Successfull Docker Image building"
            }
        }
        stage("Publish Docker Image"){
            steps{

                 publishImage("dockerhub_cred","url-shortener-svc","latest")

            }
        }
        stage("Test"){
            steps{
                echo "testing code"
            }
        }
        stage("Deploy"){
            steps{
                echo "deploying code"
            }
        }
        stage("End"){
            steps{
                echo "Finished Pipeline"
            }
        }
    }
}
