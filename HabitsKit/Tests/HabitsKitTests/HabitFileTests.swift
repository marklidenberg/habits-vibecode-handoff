import Foundation
import Testing
@testable import HabitsKit

@Suite struct HabitFileTests {
    let today = Day(iso: "2026-10-06")!

    func sample() -> HabitFile.Contents {
        var water = Habit(icon: "💧", name: "Вода", step: 1, weight: 2)
        water.setValue(3, on: today.adding(-3))
        water.setValue(Habit.skipped, on: today.adding(-2))
        water.setValue(8, on: today)
        water.setNote("Только половину", on: today.adding(-1))
        var run = Habit(icon: "🏃", name: "Бег", archived: true)
        run.setValue(1, on: today)
        return HabitFile.Contents(habits: [water, run, Habit(icon: "🧘", name: "Медитация")], color: "#8fa2ff")
    }

    @Test func roundTrip() throws {
        let sample = sample()
        let read = try HabitFile.read(try HabitFile.write(sample))
        #expect(read.habits == sample.habits)
        #expect(read.color == "#8fa2ff")
    }

    @Test func compactLog() throws {
        let json = String(decoding: try Gzip.decompress(try HabitFile.write(sample())), as: UTF8.self)
        #expect(json.contains("\"from\":\"2026-10-03\""))
        #expect(json.contains("\"log\":[3,-1,0,8]"))
        #expect(!json.contains("\n"))
    }

    @Test func plainJsonRead() throws {
        let json = ##"{"v":1,"color":"#fff","habits":[{"icon":"🏃","name":"Бег","step":0,"archived":false,"from":"2026-10-05","log":[1,1]}]}"##
        let read = try HabitFile.read(Data(json.utf8))
        #expect(read.habits[0].log == [today: 1, today.adding(-1): 1])
        #expect(read.habits[0].id.count == 8)
    }

    @Test func gunzipReadsIt() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "habits-\(UUID()).json.gz")
        defer { try? FileManager.default.removeItem(at: url) }
        try HabitFile.write(sample()).write(to: url)
        let gunzip = Process()
        gunzip.executableURL = URL(filePath: "/usr/bin/gunzip")
        gunzip.arguments = ["-t", url.path]
        try gunzip.run()
        gunzip.waitUntilExit()
        #expect(gunzip.terminationStatus == 0)
    }

    @Test func corrupt() {
        #expect(throws: (any Error).self) { try HabitFile.read(Data([0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0xff, 1, 2, 3, 4, 5, 6, 7, 8])) }
    }

    @Test func name() {
        #expect(HabitFile.name(on: today) == "habits-2026-10-06.json.gz")
    }
}
