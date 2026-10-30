import Foundation
import Testing

@testable import SkillcaskUI

/// `SplitViewFrames`: a saved column layout of the main window whose visible columns overlap, or that does not
/// parse, is dropped before the window opens; a sound one, another window's, and every other default are kept.
@Suite struct SplitViewFramesTests {
    private static let key = "NSSplitView Subview Frames main-AppWindow-1, SidebarNavigationSplitView"

    /// A sound layout as AppKit wrote it: sidebar 180, a 1 pt divider, list 415, detail 672.
    private static let sound = [
        "0.000000, 0.000000, 180.000000, 726.000000, NO, NO",
        "181.000000, 0.000000, 415.000000, 726.000000, NO, NO",
        "597.000000, 0.000000, 672.000000, 726.000000, NO, NO",
    ]

    /// The layout from the report, as AppKit saves a sidebar collapsed at quit: flags `NO`, the sidebar's last width,
    /// the list at x 0 under it. The window opened with empty columns and hung, then crashed, on a sidebar toggle.
    private static let overlapping = [
        "0.000000, 0.000000, 228.000000, 1852.000000, NO, NO",
        "0.000000, 0.000000, 613.000000, 1852.000000, NO, NO",
        "614.000000, 0.000000, 784.000000, 1852.000000, NO, NO",
    ]

    @Test func aSoundLayoutIsKept() {
        #expect(SplitViewFrames.unsoundKeys([Self.key: Self.sound]).isEmpty)
    }

    @Test func overlappingColumnsAreDropped() {
        #expect(SplitViewFrames.unsoundKeys([Self.key: Self.overlapping]) == [Self.key])
    }

    @Test func aSidebarCollapsedAtQuitIsDropped() {
        let collapsedAtQuit = [
            "0.000000, 0.000000, 180.000000, 726.000000, NO, NO",
            "0.000000, 0.000000, 415.000000, 726.000000, NO, NO",
            "416.000000, 0.000000, 672.000000, 726.000000, NO, NO",
        ]
        #expect(SplitViewFrames.unsoundKeys([Self.key: collapsedAtQuit]) == [Self.key])
    }

    @Test func aColumnFlaggedCollapsedOrHiddenIsNotCompared() {
        let sidebarCollapsed = [
            "0.000000, 0.000000, 0.000000, 726.000000, YES, NO",
            "0.000000, 0.000000, 415.000000, 726.000000, NO, NO",
            "416.000000, 0.000000, 672.000000, 726.000000, NO, NO",
        ]
        let listHidden = [
            "0.000000, 0.000000, 180.000000, 726.000000, NO, NO",
            "0.000000, 0.000000, 415.000000, 726.000000, NO, YES",
            "181.000000, 0.000000, 672.000000, 726.000000, NO, NO",
        ]
        #expect(SplitViewFrames.unsoundKeys([Self.key: sidebarCollapsed]).isEmpty)
        #expect(SplitViewFrames.unsoundKeys([Self.key: listHidden]).isEmpty)
    }

    @Test func aRightToLeftLayoutIsJudgedTheSameWay() {
        let mirrored = Array(Self.sound.reversed())
        let mirroredOverlapping = Array(Self.overlapping.reversed())
        #expect(SplitViewFrames.unsoundKeys([Self.key: mirrored]).isEmpty)
        #expect(SplitViewFrames.unsoundKeys([Self.key: mirroredOverlapping]) == [Self.key])
    }

    @Test func fractionalFramesThatTouchAreKept() {
        let frames = [
            "0.000000, 0.000000, 180.500000, 726.000000, NO, NO",
            "180.250000, 0.000000, 415.000000, 726.000000, NO, NO",
        ]
        #expect(SplitViewFrames.unsoundKeys([Self.key: frames]).isEmpty)
    }

    @Test func aLayoutThatDoesNotParseIsDropped() {
        let cases: [Any] = [
            "0, 0, 180, 726, NO, NO",
            ["0.000000, 0.000000, 180.000000, 726.000000, NO"],
            ["0.000000, 0.000000, wide, 726.000000, NO, NO"],
            ["0.000000, 0.000000, -1.000000, 726.000000, NO, NO"],
            ["0.000000, 0.000000, 180.000000, 726.000000, MAYBE, NO"],
            ["0.000000, 0.000000, inf, 726.000000, NO, NO"],
            [1, 2, 3],
        ]
        for value in cases {
            #expect(SplitViewFrames.unsoundKeys([Self.key: value]) == [Self.key], "\(value)")
        }
    }

    @Test func otherWindowsAndOtherDefaultsAreLeftAlone() {
        let values: [String: Any] = [
            "NSSplitView Subview Frames SwiftUI.ModifiedContent<Old>-1-AppWindow-1, SidebarNavigationSplitView":
                Self.overlapping,
            "NSSplitView Subview Frames com_apple_SwiftUI_Settings_window, Split": Self.overlapping,
            "NSSplitView Subview Frames mainframe-AppWindow-1, SidebarNavigationSplitView": Self.overlapping,
            "NSWindow Frame main-AppWindow-1": "256 212 1398 809 0 0 1728 1084 ",
            "lastScope": "personal",
        ]
        #expect(SplitViewFrames.unsoundKeys(values).isEmpty)
    }

    @Test func everyMainWindowIsChecked() {
        let second = "NSSplitView Subview Frames main-AppWindow-2, SidebarNavigationSplitView"
        let bare = "NSSplitView Subview Frames main, SidebarNavigationSplitView"
        let values: [String: Any] = [Self.key: Self.sound, second: Self.overlapping, bare: Self.overlapping]
        #expect(SplitViewFrames.unsoundKeys(values) == [bare, second])
    }

    @Test func repairRemovesOnlyTheUnsoundKeysAndReportsThem() {
        let defaults = MemoryDefaults.make()
        let second = "NSSplitView Subview Frames main-AppWindow-2, SidebarNavigationSplitView"
        defaults.set(Self.overlapping, forKey: Self.key)
        defaults.set(Self.sound, forKey: second)
        defaults.set("personal", forKey: "lastScope")
        #expect(SplitViewFrames.repair(defaults) == [Self.key])
        #expect(defaults.object(forKey: Self.key) == nil)
        #expect(defaults.object(forKey: second) != nil)
        #expect(defaults.string(forKey: "lastScope") == "personal")
        #expect(SplitViewFrames.repair(defaults).isEmpty)
    }
}
