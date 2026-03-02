//
//  MainTabView.swift
//  Dashboard
//
//  Created by FinFlow AI.
//

import SwiftUI

public struct MainTabView<ProfileContent: View>: View {
    private let profileView: ProfileContent
    
    public init(profileView: ProfileContent) {
        self.profileView = profileView
    }
    
    public var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Trang chủ", systemImage: "house.fill")
                }
            
            profileView
                .tabItem {
                    Label("Tài khoản", systemImage: "person.fill")
                }
        }
    }
}
