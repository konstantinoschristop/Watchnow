//
//  ContentView.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/7/21.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        TabView {
            NavigationView {
                MoviesView()
                    .background(Color(.systemBackground))
                    .navigationBarTitle("Movies")
            }
            .navigationBarTitleDisplayMode(.inline)
            .tabItem {
                Label("Movies", systemImage: "film")
            }
            
            NavigationView {
                SerieView()
                    .background(Color(.systemBackground))
                    .navigationBarTitle("Series")
            }
            .navigationBarTitleDisplayMode(.inline)
            .tabItem {
                Label("Series", systemImage: "tv.inset.filled")
            }
            
            NavigationView {
               
            }
            .navigationBarTitleDisplayMode(.inline)
            .tabItem {
                Label("Search", systemImage: "magnifyingglass.circle")
            }
            
            NavigationView {
               
            }
            .navigationBarTitleDisplayMode(.inline)
            .tabItem {
                Label("Profile", systemImage: "person.circle.fill")
            }
        }
    }
}


















//
//struct ContentView: View {
//
//    @ObservedObject var movieService = Services()
//    @State var upcomingMoviesModel: UpcomingMoviesViewModel?
//    @State var upcomingImages: [UIImage] = []
//    @State var popularMoviesModel: PopularMoviesViewModel?
//    @State var popularImages: [UIImage] = []
//
//
//    init() {
//    }
//
//    var body: some View {
//
//        if upcomingReady == true && popularReady == true && upcomingMoviesModel != nil && popularMoviesModel != nil {
//            TabView {
//                MoviesView(upcomingModel: upcomingMoviesModel!, popularModel: popularMoviesModel!)
//                    .background(Color(.systemBackground))
//                    .tabItem {
//                        Label("Movies", systemImage: "film")
//                    }
//        }
//        } else {
//            ProgressView()
//                .onAppear(perform: {
//                    fetchUpcoming()
//                    fetchPopular()
//                })
//        }
//    }
//
//    fileprivate func fetchPopular() {
//        movieService.fetchPopularMovies { (popularModel) in
//            if let pModel = popularModel {
//                popularMoviesModel = pModel
//                popularReady = true
//            }
//        }
//    }
//
//    fileprivate func fetchUpcoming() {
//        movieService.fetchUpcomingMovies { (upcomingModel) in
//            if let uModel = upcomingModel {
//                upcomingMoviesModel = uModel
//                upcomingReady = true
//            }
//        }
//    }
//}
//
//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
