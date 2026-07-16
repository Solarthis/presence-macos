public enum ExamplePolicies {
    public static let simpleAbsenceJSON = #"{"schemaVersion":1,"name":"Walk-away protection","rules":[{"trigger":"absence","graceSeconds":30,"minConfidence":0.6,"actions":["curtain"]}],"restoration":{"requireAuth":true}}"#

    public static let hideAppsAbsenceJSON = #"{"schemaVersion":1,"name":"Private apps after one minute","rules":[{"trigger":"absence","graceSeconds":60,"minConfidence":0.6,"actions":["curtain","hideApps"],"hideAppBundleIds":["com.example.PrivateApp"]}],"restoration":{"requireAuth":true}}"#

    public static let additionalViewerJSON = #"{"schemaVersion":1,"name":"Shoulder privacy","rules":[{"trigger":"additionalViewer","graceSeconds":5,"minPersons":2,"minConfidence":0.6,"actions":["curtain"]}],"restoration":{"requireAuth":true}}"#

    public static let jsonStrings = [
        simpleAbsenceJSON,
        hideAppsAbsenceJSON,
        additionalViewerJSON,
    ]

    public static let phrases = [
        "Protect my screen when I walk away for 30 seconds",
        "Protect my screen and hide private apps when I walk away for 60 seconds",
        "Raise the curtain when another person is visible for 5 seconds",
    ]
}
