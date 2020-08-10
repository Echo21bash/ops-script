if(project.equals("gateway")){

    def gettags = ("git ls-remote -h ssh://git@gitssh.cnzhiyuanhui.com:32121/ty-metro/backend/tyacc-ms-gateway.git").execute()

    gettags.text.readLines().collect { it.split()[1].replaceAll('refs/heads/', '') }.unique()

}else if(project.equals("report")){

    def gettags = ("git ls-remote -h ssh://git@gitssh.cnzhiyuanhui.com:32121/ty-metro/backend/tyacc-ms-report.git").execute()

    gettags.text.readLines().collect { it.split()[1].replaceAll('refs/heads/', '') }.unique()

}else {

    return ["unknow project"]
}