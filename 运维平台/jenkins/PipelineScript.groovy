node {
   //定义变量
   def version="v${BUILD_NUMBER}"
   
   stage('拉取代码') { // for display purposes
      // Get some code from a GitHub repository
      checkout([$class: 'SubversionSCM', additionalCredentials: [], excludedCommitMessages: '', excludedRegions: '', excludedRevprop: '', excludedUsers: '', filterChangelog: false, ignoreDirPropChanges: false, includedRegions: '', locations: [[cancelProcessOnExternalsFail: true, credentialsId: 'edf429db-8dff-4487-9cdd-e6bdf97a3c67', depthOption: 'infinity', ignoreExternalsOption: true, local: '.', remote: 'svn://172.26.32.172/kuaixiu']], quietOperation: true, workspaceUpdater: [$class: 'UpdateUpdater']])

   }
   stage('构建并配置') {
      // Run the maven build
      sh '''
      sed -i "s#<spring.profiles.active>dev</spring.profiles.active>#<spring.profiles.active>test</spring.profiles.active>#" /root/.jenkins/jobs/test_kuaixiu/workspace/pom.xml
      /apps/application/maven-3.5.4/bin/mvn -Dmaven.test.skip=true clean install -pl $module -am
      '''
   }
   stage('发送') {
      sh '"\"cp /root/.jenkins/jobs/test_kuaixiu/workspace/$module/target/*.war /apps/data/sftp/www'
   }
   stage('部署') {
      sh '/apps/data/sftp/script/auto_deploy.sh $module'
   }
}
