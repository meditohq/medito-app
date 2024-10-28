//
//  StreakWidgetSmallView.swift
//  MeditoWidgetExtension
//
//  Created by Luz Racca on 27/10/2024.
//

import SwiftUI

struct StreakWidgetSmallView: View {
    var entry: MeditoTimelineProvider.Entry
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                Text("\(entry.streakValue)")
                    .font(.custom(MeditoFont.dmSerifRegular, size: 50))
                    .foregroundColor(Color.white)
                Text("\(entry.streakTitle)")
                    .font(.custom(MeditoFont.teachersRegular, size: 16))
                    .foregroundColor(Color.accentPurple)
            }
        }
        .widgetBackground(Color.deepBlue)
    }
}
