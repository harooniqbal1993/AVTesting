//
//  AddManual.swift
//  TestingProject
//
//  Created by iMac on 03/09/2020.
//  Copyright © 2020 iMac. All rights reserved.
//

import UIKit

class AddManual: UITableViewController {

    @IBOutlet var tblView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {

        return UITableView.automaticDimension
    }
    
    

}
