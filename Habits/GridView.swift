import HabitsKit
import SwiftUI

/// Habits as rows, days as columns, today on the right
struct GridView: View {
    @Environment(Store.self) var store
    @AppStorage("cell") var cell: Double = 34
    @AppStorage("outlineWidth") var outlineWidth: Double = 150
    @AppStorage("outlineNames") var outlineNames = true
    @AppStorage("folded") var folded = ""
    @State var resizing: Double?  // the width while dragged, kept on release
    @AppStorage("style") var style = "pills"
    @State var marking: Marking?
    @State var pinchedFrom: Double?
    @State var dragging: Dragging?
    @State var editing: Editing?

    @State var today = Day.today()

    var gap: Double { style == "tiles" ? 0 : (cell / 6).rounded() }
    var row: Double { cell + gap }
    var side: Double { outlineNames ? resizing ?? outlineWidth : 70 }
    var header: Double { 30 }
    var accent: Color { Color(hex: store.color) }

    /// The active, a folded group's habits left out
    var rows: [Habit] {
        let folded = foldedIDs
        return store.active.filter { !store.ancestors($0).contains { folded.contains($0.id) } }
    }

    var foldedIDs: Set<Habit.ID> {
        Set(folded.split(separator: ",").map(String.init))
    }

    /// Two months at least, back to the first mark
    var days: [Day] {
        let first = store.active.flatMap(\.log.keys).min() ?? today
        return (min(first, today.adding(-59)).index...today.index).map(Day.init)
    }

    var body: some View {
        ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                cells
                outline
            }
            .padding(.trailing, 12)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .leading) { grip }
        .sheet(item: $marking) { MarkSheet(marking: $0) }
        .sheet(item: $editing) { HabitSheet($0) }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("New", systemImage: "plus") {
                    editing = Editing(habit: Habit(icon: "✨", name: ""), isNew: true)
                }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("new")
            }
        }
        .simultaneousGesture(zoom)
        .toolbar {
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Zoom out", systemImage: "minus.magnifyingglass") { step(by: 1 / 1.25) }
                    .disabled(cell <= 18)
                    .accessibilityIdentifier("zoom-out")
                Button("Zoom in", systemImage: "plus.magnifyingglass") { step(by: 1.25) }
                    .disabled(cell >= 60)
                    .accessibilityIdentifier("zoom-in")
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityIdentifier("settings")
            }
        }
    }

    func step(by factor: Double) {
        withAnimation(.snappy) { cell = min(max(cell * factor, 18), 60).rounded() }
    }

    var zoom: some Gesture {
        MagnifyGesture()
            .onChanged { pinch in
                let from = pinchedFrom ?? cell
                pinchedFrom = from
                cell = min(max(from * pinch.magnification, 18), 60).rounded()
            }
            .onEnded { _ in pinchedFrom = nil }
    }

    @ViewBuilder var cells: some View {
        let rows = rows
        ScrollView(.horizontal) {
            Cells(days: days, rows: rows, today: today, cell: cell, gap: gap, header: header, inset: style == "tiles" ? 0 : 4, accent: accent) {
                marking = Marking(habit: $0, day: $1)
            }
            .equatable()
            .padding(.leading, side)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.trailing)
        .accessibilityIdentifier("cells")
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in today = .today() }
        .mask {
            HStack(spacing: 0) {
                Color.clear.frame(width: side - 4)
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 18)
                Color.black
            }
        }
    }

    @ViewBuilder var outline: some View {
        let rows = rows
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.snappy) { outlineNames.toggle() } } label: {
                Text("Aa")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(outlineNames ? 0.9 : 0.5))
                    .frame(width: 32, height: 24)
                    .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
            .frame(height: header)
            .accessibilityIdentifier("names")
            ForEach(rows) { habit in
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .rotationEffect(.degrees(foldedIDs.contains(habit.id) ? 0 : 90))
                        .frame(width: 12)
                        .opacity(habit.group ? 1 : 0)
                    if !habit.group {
                        handle(Text(habit.icon).font(.system(size: cell * 0.55)), habit)
                    }
                    if outlineNames {
                        let name = Text(habit.name)
                            .font(.system(size: 13, weight: habit.group ? .semibold : .regular))
                            .foregroundStyle(.white.opacity(habit.group ? 1 : 0.8))
                            .lineLimit(1)
                        if habit.group { handle(name, habit) } else { name }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 4 + Double(store.ancestors(habit).count) * 14)
                .frame(width: side - 4, height: row, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { if habit.group { fold(habit.id) } }
            }
        }
        .frame(width: side, alignment: .leading)
        .animation(.snappy(duration: 0.2), value: rows.map(\.id))
        .sensoryFeedback(.impact, trigger: dragging?.habit)
    }

    /// A habit's emoji, a group's name: a tap edits, a hold drags
    func handle(_ label: some View, _ habit: Habit) -> some View {
        label
            .scaleEffect(dragging?.habit == habit.id ? 1.35 : 1)
            .contentShape(Rectangle())
            .onTapGesture { editing = Editing(habit: habit, isNew: false) }
            .accessibilityElement()
            .accessibilityIdentifier("emoji-\(habit.name)")
            .accessibilityAddTraits(.isButton)
            .gesture(reorder(habit))
    }

    func fold(_ id: Habit.ID) {
        var ids = foldedIDs
        if ids.remove(id) == nil { ids.insert(id) }
        withAnimation(.snappy) { folded = ids.sorted().joined(separator: ",") }
    }

    /// The tree's edge, dragged: its width
    @ViewBuilder var grip: some View {
        if outlineNames {
            Capsule()
                .fill(.white.opacity(0.35))
                .frame(width: 5, height: 40)
                .frame(width: 25, height: 80)
                .contentShape(Rectangle())
                .offset(x: side - 12 - 10)
                .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { drag in resizing = max(outlineWidth + drag.translation.width, 0).rounded() }
                    .onEnded { _ in
                        outlineWidth = resizing ?? outlineWidth
                        resizing = nil
                    })
                .accessibilityIdentifier("grip")
        }
    }

    struct Dragging {
        let habit: Habit.ID
        let from: Int
    }

    func reorder(_ habit: Habit) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                let rows = rows
                let block = Set(store.subtree(habit.id).map(\.id))
                let others = rows.filter { !block.contains($0.id) }
                let from = dragging?.from ?? rows.firstIndex { $0.id == habit.id } ?? 0
                dragging = Dragging(habit: habit.id, from: from)
                let to = min(max(from + Int(((drag?.translation.height ?? 0) / row).rounded()), 0), others.count)
                let after = to > 0 ? others[to - 1] : nil
                let parent = after.flatMap { $0.group && !foldedIDs.contains($0.id) ? $0.id : $0.parent }
                let above = rows.prefix { $0.id != habit.id }.last
                if above?.id != after?.id || store.habit(habit.id)?.parent != parent {
                    store.move(habit.id, after: after?.id, parent: parent)
                }
            }
            .onEnded { _ in dragging = nil }
    }
}

/// The days' header and every row's cells: redrawn only when they change
struct Cells: View, Equatable {
    let days: [Day]
    let rows: [Habit]
    let today: Day
    let cell: Double
    let gap: Double
    let header: Double
    let inset: Double
    let accent: Color
    let hold: (Habit.ID, Day) -> Void
    let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var row: Double { cell + gap }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 0) {
                        Text(weekdays[day.weekday])
                        Text("\(day.day)")
                    }
                    .font(.system(size: 10, weight: day == today ? .bold : .regular))
                    .foregroundStyle(day == today ? Color.white.mix(with: accent, by: 0.3) : Color(hex: "#8a8a96").mix(with: accent, by: 0.45))
                    .frame(width: row, height: header)
                }
            }
            ForEach(rows) { habit in
                HStack(spacing: 0) {
                    ForEach(habit.group ? [] : days, id: \.self) { day in
                        DayCell(habit: habit, day: day, cell: cell, gap: gap, rows: rows) {
                            hold(habit.id, day)
                        }
                    }
                }
                .frame(height: row)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Canvas { context, size in
                context.addFilter(.alphaThreshold(min: 0.93, color: Color(hex: "#3a3a42").mix(with: accent, by: 0.25)))
                context.addFilter(.blur(radius: inset / 1.5))
                context.drawLayer { $0.draw(context.resolveSymbol(id: 0)!, at: CGPoint(x: 0, y: size.height), anchor: .bottomLeading) }
            } symbols: {
                VStack(spacing: 0) {
                    ForEach(rows) { habit in
                        HStack(spacing: 0) {
                            ForEach(habit.group ? [] : days, id: \.self) { day in
                                SkipCell(habit: habit, day: day, cell: cell, gap: gap, rows: rows)
                            }
                        }
                        .frame(height: row)
                    }
                }
                .tag(0)
            }
            .allowsHitTesting(false)
        }
    }

    static func == (a: Cells, b: Cells) -> Bool {
        a.days == b.days && a.rows == b.rows && a.today == b.today && a.cell == b.cell && a.gap == b.gap && a.header == b.header && a.inset == b.inset && a.accent == b.accent
    }
}

/// A day of a habit: the accent when marked, a counter's number inside, marked or skipped neighbors joined
struct DayCell: View {
    @Environment(Store.self) var store
    @AppStorage("style") var style = "pills"
    @AppStorage("chime") var chime = Chime.off

    let habit: Habit
    let day: Day
    let cell: Double
    let gap: Double
    let rows: [Habit]
    let hold: () -> Void
    /// The last cleared: its cell and when
    static var cleared = (cell: "", at: Date.distantPast)
    /// The last tap: its cell, when, the value before it
    static var tapped = (cell: "", at: Date.distantPast, before: 0)

    var body: some View {
        let marked = habit.isMarked(on: day)
        let skipped = habit.isSkipped(on: day)
        let near = store.around(habit, day, rows) { $0.isMarked(on: $1) || $0.isSkipped(on: $1) }
        let tiles = style == "tiles"
        let radius = tiles ? 0 : cell / 2
        let fillet = tiles ? 0 : 8.0
        let accent = Color(hex: store.color)

        Blob(near: near, radius: radius, gap: gap, fillet: fillet)
        .fill(marked || skipped ? accent : accent.opacity(0.14))
        .shadow(color: marked && !tiles ? accent.opacity(0.35) : .clear, radius: 2)
        .overlay {
            if marked && !habit.isBinary {
                Text("\(habit.value(on: day))")
                    .font(.system(size: cell * (habit.value(on: day) >= 100 ? 0.32 : 0.42), weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color(hex: "#0b0d24"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(height: cell)
        .padding(.leading, near[1][0] ? 0 : gap / 2)
        .padding(.trailing, near[1][2] ? 0 : gap / 2)
        .frame(width: cell + gap)
        .contentShape(Rectangle())
        .onTapGesture {
            let id = "\(habit.id)-\(day.index)"
            guard DayCell.cleared.cell != id || Date.now.timeIntervalSince(DayCell.cleared.at) > 0.3 else { return }
            if DayCell.tapped.cell != id || Date.now.timeIntervalSince(DayCell.tapped.at) > 0.5 {
                DayCell.tapped = (id, .now, habit.value(on: day))
            }
            store.tap(habit.id, on: day)
            if store.active.first(where: { $0.id == habit.id })!.value(on: day) > max(habit.value(on: day), 0) { chime.play() }
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            let id = "\(habit.id)-\(day.index)"
            store.doubleTap(habit.id, on: day, before: DayCell.tapped.cell == id ? DayCell.tapped.before : habit.value(on: day))
            DayCell.cleared = (id, .now)
        })
        .onLongPressGesture(minimumDuration: 0.25, perform: hold)
        .sensoryFeedback(.selection, trigger: habit.value(on: day))
        .accessibilityElement()
        .accessibilityIdentifier("cell-\(habit.name)-\(day.index - Day.today().index)")
        .accessibilityValue("\(habit.value(on: day))")
        .accessibilityAddTraits(.isButton)
    }
}

/// A skipped day, joined to skipped alone
struct SkipCell: View {
    @Environment(Store.self) var store
    @AppStorage("style") var style = "pills"

    let habit: Habit
    let day: Day
    let cell: Double
    let gap: Double
    let rows: [Habit]

    var body: some View {
        let skips = store.around(habit, day, rows) { $0.isSkipped(on: $1) }
        let tiles = style == "tiles"

        Blob(near: skips, radius: tiles ? 0 : cell / 2, gap: gap, fillet: tiles ? 0 : 8)
            .fill(habit.isSkipped(on: day) ? Color.black : .clear)
            .frame(height: cell)
            .padding(.leading, skips[1][0] ? 0 : gap / 2)
            .padding(.trailing, skips[1][2] ? 0 : gap / 2)
            .frame(width: cell + gap)
    }
}

extension Store {
    /// The days around a day, a row up and down too: joined where both join
    func around(_ habit: Habit, _ day: Day, _ rows: [Habit], joins: (Habit, Day) -> Bool) -> [[Bool]] {
        let row = rows.firstIndex { $0.id == habit.id } ?? 0
        return (-1...1).map { dy in
            (-1...1).map { dx in joins(habit, day) && rows.indices.contains(row + dy) && joins(rows[row + dy], day.adding(dx)) }
        }
    }
}

/// A cell, square on a joined side; the gap toward a joined neighbor above or below filled, an inner corner rounded
struct Blob: Shape {
    let near: [[Bool]]
    let radius: Double
    let gap: Double
    let fillet: Double

    func path(in rect: CGRect) -> Path {
        let at = { (dx: Int, dy: Int) in near[dy + 1][dx + 1] }
        let x0 = at(-1, 0) ? gap / 2 : 0
        let x1 = rect.width - (at(1, 0) ? gap / 2 : 0)
        var path = Path(roundedRect: rect, cornerRadii: RectangleCornerRadii(
            topLeading: at(-1, 0) || at(0, -1) ? 0 : radius,
            bottomLeading: at(-1, 0) || at(0, 1) ? 0 : radius,
            bottomTrailing: at(1, 0) || at(0, 1) ? 0 : radius,
            topTrailing: at(1, 0) || at(0, -1) ? 0 : radius
        ))
        for dy in [-1, 1] where at(0, dy) {
            let from = at(-1, 0) && at(-1, dy) ? 0 : x0
            let to = at(1, 0) && at(1, dy) ? rect.width : x1
            path.addRect(CGRect(x: from, y: dy < 0 ? -gap / 2 : rect.height, width: to - from, height: gap / 2))

            for dx in [-1, 1] where at(dx, 0) && !at(dx, dy) {
                let corner = CGPoint(x: dx < 0 ? x0 : x1, y: dy < 0 ? 0 : rect.height)
                path.move(to: corner)
                path.addLine(to: CGPoint(x: corner.x + Double(dx) * fillet, y: corner.y))
                path.addArc(tangent1End: corner, tangent2End: CGPoint(x: corner.x, y: corner.y + Double(dy) * fillet), radius: fillet)
                path.closeSubpath()
            }
        }
        return path
    }
}
