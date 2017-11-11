//
//  SystemViewController.swift
//  radar
//
//  Created by Jason Lee on 08/04/2017.
//  Copyright © 2017 JasonDevelop. All rights reserved.
//

import Foundation
import UIKit

class SystemSegmentTableViewCell: JDTableViewCell {
    
    //MARK: * Properties --------------------
    override class var height: CGFloat { return 72.0 }
    var btnFunc: ((Int)->()?)?
    
    //MARK: * IBOutlets --------------------
    @IBOutlet weak var btnInfo: JDButton! {
        didSet {
            btnInfo.reactive.controlEvents(.touchUpInside).filter({ !$0.isSelected}).observeValues { [weak self] in
                $0.isSelected = !$0.isSelected
                self?.btnSetup.isSelected = !$0.isSelected
                
                self?.btnFunc?(0)
            }
        }
    }
    @IBOutlet weak var btnSetup: JDButton! {
        didSet {
            btnSetup.reactive.controlEvents(.touchUpInside).filter({ !$0.isSelected}).observeValues { [weak self] in
                $0.isSelected = !$0.isSelected
                self?.btnInfo.isSelected = !$0.isSelected
                
                self?.btnFunc?(1)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func invalidateIntrinsicContentSize() {
        
    }
}

class SystemContainerTableViewCell: JDTableViewCell {
    @IBOutlet weak var container: JDView!
    
}

class SystemViewController: JDViewController {

    //MARK: * properties --------------------
    var segmentTableViewCell: SystemSegmentTableViewCell?
    
    lazy var pageViewController: UIPageViewController? = { [weak self] in
        let pc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        pc.setViewControllers(self?.infoViewControllers, direction: .forward, animated: false, completion: nil)
        
        //PageViewController를 현재의 뷰에 추가, 페이지가 전체 화면을 가득 채우도록 처리
        self?.addChildViewController(pc)
////                
////                pageViewController.view.frame = cell.container.bounds //CGRect(x: 0, y: 50, width: JDScreenSize.width, height: JDScreenSize.height-50)
////                pageViewController.didMoveToParentViewController(self)
//            }
//        })
        return pc
    }()
    
    lazy var infoViewControllers: [UIViewController] = {
        return [JDFacade.ux.screens(.system(.info)).instantiate()]
    }()
    
    lazy var setupViewControllers: [UIViewController] = {
        return [JDFacade.ux.screens(.system(.setup)).instantiate()]
    }()

    lazy var refreshControl: UIRefreshControl = { [unowned self] in
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(SystemViewController.handleRefresh(refreshControl:)), for: .valueChanged)
        return refreshControl
        }()

    //MARK: * IBOutlets --------------------
    @IBOutlet weak var tableView: JDTableView! {
        willSet(v) {
            v.dataSource = self
            v.delegate = self
            
            v.separatorStyle = .none
            v.tableFooterView = UIView() //this call table events
            //tableView.tableFooterView?.backgroundColor = .clearColor()
            v.addSubview(self.refreshControl)
        }
    }

    //MARK: * Initialize --------------------

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initProperties()
        self.initUI()
        self.prepareViewDidLoad()
    }


    private func initProperties() {
    }


    private func initUI() {
    }


    func prepareViewDidLoad() {

    }

    //MARK: * Main Logic --------------------
    func handleRefresh(refreshControl: UIRefreshControl) {
        
        if let vc = self.pageViewController?.viewControllers?.first as? JDViewController {
            vc.refreshViewController()
        } else if let vc = self.pageViewController?.viewControllers?.first as? JDTableViewController {
            vc.refreshViewController()
        }
        
        refreshControl.endRefreshing()
    }

    //MARK: * UI Events --------------------
    func changePageIndex(index: Int) {
        
        let direction: UIPageViewControllerNavigationDirection = index == 1 ? .forward : .reverse
        let viewControllers = direction == .forward ? setupViewControllers : infoViewControllers
        
        self.pageViewController?.setViewControllers(viewControllers, direction: direction, animated: false, completion: nil)
        
        self.tableView.reloadData()
    }

    //MARK: * Memory Manage --------------------

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}


extension SystemViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        var height = 0.c
        if indexPath.section == 0 {
            height = SystemSegmentTableViewCell.height // (tableView as? JDTableView)?.dequeueReusableCell(type: SystemSegmentTableViewCell.self)?.height ?? 0
        } else if indexPath.section == 1 {
            if let viewControllers = self.pageViewController?.viewControllers {
                height = viewControllers == infoViewControllers ? 696 : 1135//(tableView as? JDTableView)?.dequeueReusableCell(type: SystemContainerTableViewCell.self)?.height ?? 0
            }
        }
        
        return height
    }
    
    /** cellForRowAtIndexPath */
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        
        if indexPath.section == 0 {
            if self.segmentTableViewCell == nil {
                self.segmentTableViewCell = (tableView as? JDTableView)?.dequeueReusableCell(type: SystemSegmentTableViewCell.self)?.then({ [weak self] in
                    $0.btnFunc = self?.changePageIndex
                })
            }
            
            cell = self.segmentTableViewCell
            
        } else if indexPath.section == 1 {
            
            cell = (tableView as? JDTableView)?.dequeueReusableCell(type: SystemContainerTableViewCell.self)?.then({ [weak self] in
                if let pc = self?.pageViewController, $0.container.subviews.count == 0 {
                    $0.container.addSubview(pc.view)
                    pc.view.snp.makeConstraints({ (make) in
                        make.edges.equalToSuperview()
                    })
                }
            })
            
        }
        
        return cell
    }
    
    /** willDisplayCell */
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
//        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
    }
    
    /** didSelectRow */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        super.tableView(tableView, didSelectRowAt: indexPath)
    }
}
