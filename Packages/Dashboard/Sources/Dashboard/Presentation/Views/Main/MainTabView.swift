//
//  MainTabView.swift
//  Dashboard
//
//  Created by FinFlow AI.
//

import SwiftUI

public struct MainTabView<ProfileContent: View, TransactionContent: View>: View {
    private let profileView: ProfileContent
    private let transactionView: TransactionContent
    
    public init(profileView: ProfileContent, transactionView: TransactionContent) {
        self.profileView = profileView
        self.transactionView = transactionView
    }
    
    public var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Trang chủ", systemImage: "house.fill")
                }
            
            transactionView
                .tabItem {
                    Label("Giao dịch", systemImage: "list.clipboard.fill")
                }
            
            profileView
                .tabItem {
                    Label("Tài khoản", systemImage: "person.fill")
                }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
