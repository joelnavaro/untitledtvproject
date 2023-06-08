//
//  RowView.swift
//  untitledtvproject
//
//  Created by Joel Pena Navarro on 2023-06-05.
//

import Foundation
import SwiftUI

import FirebaseCore
import FirebaseAuth
import Firebase
import FirebaseFirestoreSwift
import FirebaseFirestore

struct RowView : View {
    var showView : ApiShows.ShowReturned
    @State var showingAlert = false
    @State var listChoice = ""
    @State var collectionPath = ""
    
    let db = Firestore.firestore()
    @StateObject var showList = ShowList()
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .onTapGesture {
                    showingAlert = true
                    listenToFireStore(collection: "watching")
                    listenToFireStore(collection: "completed")
                    listenToFireStore(collection: "dropped")
                    listenToFireStore(collection: "wantToWatch")
                    listenToFireStore(collection: "recentlyDeleted")
                    //fireStoreManager.listenToFireStore()
                }
            Text(showView.show.name)
        }
        .alert("Move to what list?", isPresented: $showingAlert) {
            VStack {
                Button("Want to watch") {
                    listChoice = "wantToWatch"
                    changeListFireStore()
                }
                Button("Watching") {
                    listChoice = "watching"
                    changeListFireStore()
                }
                Button("Completed") {
                    listChoice = "completed"
                    changeListFireStore()
                }
                Button("Dropped") {
                    listChoice = "dropped"
                    changeListFireStore()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    func listenToFireStore(collection: String) {
        
        guard let user = Auth.auth().currentUser else {return}
        
        db.collection("users").document(user.uid).collection(collection).addSnapshotListener { snapshot, err in
            guard let snapshot = snapshot else {return}
            
            if let err = err {
                print("Error getting document \(err)")
            } else {
                
            //clear the list corresponding to the collection
                if collection == "watching"{
                    showList.lists[.watching]?.removeAll()
                }else if collection == "completed"{
                    showList.lists[.completed]?.removeAll()
                }else if collection == "dropped"{
                    showList.lists[.dropped]?.removeAll()
                }else if collection == "wantToWatch"{
                    showList.lists[.wantToWatch]?.removeAll()
                }else if collection == "recentlyDeleted"{
                    showList.lists[.recentlyDeleted]?.removeAll()
                }
                
                for document in snapshot.documents {
                    let result = Result {
                        try document.data(as: ApiShows.ShowReturned.self)
                    }
                    switch result  {
                    case .success(let show)  :
                //adds the show to the corresponding list
                        if collection == "watching"{
                            showList.lists[.watching]?.append(show)
                        }else if collection == "completed"{
                            showList.lists[.completed]?.append(show)
                        }else if collection == "dropped"{
                            showList.lists[.dropped]?.append(show)
                        }else if collection == "wantToWatch"{
                            showList.lists[.wantToWatch]?.append(show)
                        }else if collection == "recentlyDeleted"{
                            showList.lists[.recentlyDeleted]?.append(show)
                        }
                    case .failure(let error) :
                        print("Error decoding item: \(error)")
                    }
                }
            }
        }
    }
    func detectTappedList() { //Detects what list has been tapped and sets the collectionpath to what firestore document should be deleted
        for item in showList.lists[.wantToWatch]! {
            if item.show.name == showView.show.name {
                collectionPath = "wantToWatch"
            }
        }
        for item in showList.lists[.watching]! {
            if item.show.name == showView.show.name {
                collectionPath = "watching"
            }
        }
        for item in showList.lists[.completed]! {
            if item.show.name == showView.show.name {
                collectionPath = "completed"
            }
        }
        for item in showList.lists[.dropped]! {
            if item.show.name == showView.show.name {
                collectionPath = "dropped"
            }
        }
        for item in showList.lists[.recentlyDeleted]! {
            if item.show.name == showView.show.name {
                collectionPath = "recentlyDeleted"
            }
        }
    }
    func changeListFireStore() { //moves document to other collection + deletes the one in the previous list
        detectTappedList()
        var deleteList : [ApiShows.ShowReturned] = [] //temporary list to deal with deleted documents from firestore
        guard let user = Auth.auth().currentUser else {return}
        
        do {
            //move document to selected collection in firestore
            _ = try db.collection("users").document(user.uid).collection(listChoice).addDocument(from: showView)
            //delete tapped document from firestore
            db.collection("users").document(user.uid).collection(collectionPath).getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    for document in querySnapshot!.documents {
                        let result = Result {
                            try document.data(as: ApiShows.ShowReturned.self)
                        }
                        switch result  {
                        case .success(let show)  :
                            deleteList.removeAll()
                            deleteList.append(show)
                            for show in deleteList {
                                if show.show.name == showView.show.name {
                                    db.collection("users").document(user.uid).collection(collectionPath).document(document.documentID).delete()
                                }
                            }
                            case .failure(let error) : print("Error decoding item: \(error)") }
                    }
                }
            }
        } catch { print("catch error!") }
    }
}
