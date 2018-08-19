//
//  DefaultLayoutViewController.swift
//  DJIML
//
//  Created by Darko on 2018/8/18.
//  Copyright © 2018年 Darko. All rights reserved.
//

import UIKit
import DJIUXSDK

class DefaultLayoutViewController: DUXDefaultLayoutViewController {
    
    var isContentViewSwitched = false
    
    var oldContentViewController: DJIMLViewController?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.contentViewController = DJIMLViewController(nibName: "DJIMLViewController", bundle: Bundle.main)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
