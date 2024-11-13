//
//  ContentView.swift
//  BortoqalaAssessment
//
//  Created by Adham Raouf on 13/11/2024.
//

import SwiftUI

//
//  ContentView.swift
//  BortoqalaTechnicalAssessment
//
//  Created by Adham Raouf on 12/11/2024.
//

import SwiftUI
import Foundation
import Combine


struct Post: Identifiable, Codable {
    var id: Int
    var userId: Int
    var title: String
    var body: String
}




struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
}





class PostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var errorMessage: ErrorMessage?
    private var cancellables = Set<AnyCancellable>()
    let apiURL = "https://jsonplaceholder.typicode.com/posts"
    
    init() {
        fetchPosts()
    }
    
    func fetchPosts() {
        guard let url = URL(string: apiURL) else { return }
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: [Post].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = ErrorMessage(message: "Failed to fetch posts: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] posts in
                self?.posts = posts
            })
            .store(in: &cancellables)
    }
    
    func deletePost(_ post: Post) {
        
        guard let url = URL(string: "\(apiURL)/\(post.id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = ErrorMessage(message: "Failed to delete post: \(error.localizedDescription)")
                    
                    print("Failed to delete post: \(error.localizedDescription)")
                    return
                }
                self?.posts.removeAll { $0.id == post.id }
                print("deletePost success")
            }
        }.resume()
    }
    

 
    func addPost(title: String, body: String) {
        guard let url = URL(string: apiURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        
        let newPostData: [String: Any] = [
            "title": title,
            "body": body,
            "userId": 1
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: newPostData)
        
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.errorMessage = ErrorMessage(message: "Failed to add post: \(error?.localizedDescription ?? "Unknown error")")
                }
                return
            }
            
            do {
                let createdPost = try JSONDecoder().decode(Post.self, from: data)
                DispatchQueue.main.async {
                    self?.posts.insert(createdPost, at: 0)
                    print("addPost success, ID: \(createdPost.id)")
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = ErrorMessage(message: "Failed to decode post: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    
    func updatePost(_ post: Post, newTitle: String, newBody: String) {
        guard let url = URL(string: "\(apiURL)/\(post.id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")

        let updatedPostData: [String: Any] = [
            "id": post.id,
            "title": newTitle,
            "body": newBody,
            "userId": post.userId
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: updatedPostData)

        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.errorMessage = ErrorMessage(message: "Failed to update post: \(error?.localizedDescription ?? "Unknown error")")
                }
                return
            }
            if let updatedPost = try? JSONDecoder().decode(Post.self, from: data) {
                DispatchQueue.main.async {
                    if let index = self?.posts.firstIndex(where: { $0.id == post.id }) {
                        self?.posts[index] = updatedPost
                        print("updatePost success")
                    }
                }
            }
        }.resume()
    }
}



struct ContentView: View {
    @StateObject private var viewModel = PostsViewModel()
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                List {
                    ForEach(viewModel.posts) { post in
                        PostRow(post: post, viewModel: viewModel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Posts")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink("New Item", destination: NewPostView(viewModel: viewModel))
                    }
                }
                .alert(item: $viewModel.errorMessage) { errorMessage in
                    Alert(title: Text("Error"), message: Text(errorMessage.message), dismissButton: .default(Text("OK")))
                }
            }
        } else {
            
        }
    }
}





struct PostRow: View {
    let post: Post
    @ObservedObject var viewModel: PostsViewModel

    @State private var isEditing = false
    @State private var editedTitle: String
    @State private var editedBody: String

    init(post: Post, viewModel: PostsViewModel) {
        self.post = post
        self.viewModel = viewModel
        _editedTitle = State(initialValue: post.title)
        _editedBody = State(initialValue: post.body)
    }

    var body: some View {
        HStack {
            NavigationLink(destination: PostDetailView(post: post, viewModel: viewModel)) {
                VStack(alignment: .leading) {
                    if isEditing {
                        TextField("Edit Title", text: $editedTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("Edit Description", text: $editedBody)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(editedTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text(editedBody)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
            if isEditing {
                Button("Save") {
                    viewModel.updatePost(post, newTitle: editedTitle, newBody: editedBody)
                    
                    isEditing.toggle()
                }
                .buttonStyle(BorderlessButtonStyle())
            } else {
                Button("Edit") {
                    isEditing.toggle()
                }
                .buttonStyle(BorderlessButtonStyle())
                Button("Delete") {
                    viewModel.deletePost(post)
                }
                .foregroundColor(.red)
                .buttonStyle(BorderlessButtonStyle())
            }
        }
    }
}



struct PostDetailView: View {
    var post: Post
    @ObservedObject var viewModel: PostsViewModel

    @State private var isEditing = false
    @State private var editedTitle: String
    @State private var editedBody: String

    init(post: Post, viewModel: PostsViewModel) {
        self.post = post
        self.viewModel = viewModel
        _editedTitle = State(initialValue: post.title)
        _editedBody = State(initialValue: post.body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isEditing {
                TextField("Edit Title", text: $editedTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Edit Description", text: $editedBody)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Save") {
                    viewModel.updatePost(post, newTitle: editedTitle, newBody: editedBody)
                    viewModel.fetchPosts()
                    isEditing.toggle()
                }
                .buttonStyle(BorderlessButtonStyle())
            } else {
                Text(post.title)
                    .font(.title)
                    .fontWeight(.bold)
                Text(post.body)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                Button("Edit") {
                    isEditing.toggle()
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Details")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct NewPostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    var viewModel: PostsViewModel

    var body: some View {
        Form {
            Section(header: Text("Title")) {
                TextField("Enter title", text: $title)
            }
            Section(header: Text("Body")) {
                TextField("Enter body", text: $bodyText)
            }
            Button("Save") {
                viewModel.addPost(title: title, body: bodyText)
                
                dismiss()
            }
        }
        .navigationTitle("New Post")
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
