// swift-tools-version: 5.9

// Swift Playgrounds app package (iPad or Mac). Open this folder in Swift Playgrounds and press ▶.
// The same sources are used by ios/TeacherPrompter.xcodeproj.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Teacher Prompter",
    platforms: [
        .iOS("17.4")
    ],
    products: [
        .iOSApplication(
            name: "Teacher Prompter",
            targets: ["AppModule"],
            bundleIdentifier: "de.teacherprompter.app",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .leaf),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .pad
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources"
        )
    ]
)
