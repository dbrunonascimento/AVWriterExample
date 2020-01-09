//
//  CameraView.swift
//  AVWriterExample
//
//  Created by Ken Torimaru on 1/8/20.
//  Copyright © 2020 Torimaru & Williamson, LLC. All rights reserved.
//

import SwiftUI

struct CameraView: UIViewControllerRepresentable {
    typealias UIViewControllerType = CameraViewController
    @EnvironmentObject var state: State
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<CameraView>) ->  CameraViewController {
        let storyboard = UIStoryboard(name: "Camera", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "CameraViewController") as! CameraViewController
        return controller
    }

//    func makeCoordinator() -> CameraViewController.Coordinator {
//        return Coordinator(self)
//    }
    
    func updateUIViewController(_ uiViewController:  CameraViewController, context: UIViewControllerRepresentableContext<CameraView> ) {
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
