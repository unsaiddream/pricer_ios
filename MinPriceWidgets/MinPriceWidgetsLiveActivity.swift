//
//  MinPriceWidgetsLiveActivity.swift
//  MinPriceWidgets
//
//  Created by Sanzhar Karaulov on 22.04.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MinPriceWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct MinPriceWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MinPriceWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension MinPriceWidgetsAttributes {
    fileprivate static var preview: MinPriceWidgetsAttributes {
        MinPriceWidgetsAttributes(name: "World")
    }
}

extension MinPriceWidgetsAttributes.ContentState {
    fileprivate static var smiley: MinPriceWidgetsAttributes.ContentState {
        MinPriceWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: MinPriceWidgetsAttributes.ContentState {
         MinPriceWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: MinPriceWidgetsAttributes.preview) {
   MinPriceWidgetsLiveActivity()
} contentStates: {
    MinPriceWidgetsAttributes.ContentState.smiley
    MinPriceWidgetsAttributes.ContentState.starEyes
}
