//  Created by Thomas Evensen on 19/08/2016.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//
//  swiftlint:disable type_body_length line_length

import Cocoa
import Foundation

class ViewControllerMain: NSViewController, ReloadTable, Deselect, VcMain, Delay, FileerrorMessage, Setcolor, Checkforrsync {
    // Main tableview
    @IBOutlet var mainTableView: NSTableView!
    // Progressbar indicating work
    @IBOutlet var working: NSProgressIndicator!
    @IBOutlet var workinglabel: NSTextField!
    // Displays the rsyncCommand
    @IBOutlet var rsyncCommand: NSTextField!
    // If On result of Dryrun is presented before
    // executing the real run
    @IBOutlet var errorinfo: NSTextField!
    // number of files to be transferred
    @IBOutlet var transferredNumber: NSTextField!
    // size of files to be transferred
    @IBOutlet var transferredNumberSizebytes: NSTextField!
    // total number of files in remote volume
    @IBOutlet var totalNumber: NSTextField!
    // total size of files in remote volume
    @IBOutlet var totalNumberSizebytes: NSTextField!
    // total number of directories remote volume
    @IBOutlet var totalDirs: NSTextField!
    // Showing info about profile
    @IBOutlet var profilInfo: NSTextField!
    // New files
    @IBOutlet var newfiles: NSTextField!
    // Delete files
    @IBOutlet var deletefiles: NSTextField!
    @IBOutlet var rsyncversionshort: NSTextField!
    @IBOutlet var backupdryrun: NSButton!
    @IBOutlet var restoredryrun: NSButton!
    @IBOutlet var verifydryrun: NSButton!
    @IBOutlet var info: NSTextField!
    @IBOutlet var pathtorsyncosxschedbutton: NSButton!
    @IBOutlet var menuappisrunning: NSButton!
    @IBOutlet var profilepopupbutton: NSPopUpButton!

    // Reference to Configurations and Schedules object
    var configurations: Configurations?
    var schedules: Schedules?
    // Reference to the taskobjects
    var singletask: SingleTask?
    var executetasknow: ExecuteTaskNow?
    // Reference to Process task
    var process: Process?
    // Index to selected row, index is set when row is selected
    var index: Int?
    // Getting output from rsync
    var outputprocess: OutputProcess?
    // Reference to Schedules object
    var schedulesortedandexpanded: ScheduleSortedAndExpand?
    // Keep track of all errors
    var outputerrors: OutputErrors?

    @IBAction func rsyncosxsched(_: NSButton) {
        let running = Running()
        guard running.rsyncOSXschedisrunning == false else {
            self.info.stringValue = Infoexecute().info(num: 5)
            self.info.textColor = self.setcolor(nsviewcontroller: self, color: .green)
            return
        }
        let pathtorsyncosxschedapp: String = (ViewControllerReference.shared.pathrsyncosxsched ?? "/Applications/") + ViewControllerReference.shared.namersyncosssched
        guard running.verifypathexists(pathorfilename: pathtorsyncosxschedapp) == true else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: pathtorsyncosxschedapp))
        NSApp.terminate(self)
    }

    @IBAction func infoonetask(_: NSButton) {
        guard self.index != nil else {
            self.info.stringValue = Infoexecute().info(num: 1)
            return
        }
        guard self.checkforrsync() == false else { return }
        let task = self.configurations!.getConfigurations()[self.index!].task
        guard ViewControllerReference.shared.synctasks.contains(task) else {
            self.info.stringValue = Infoexecute().info(num: 7)
            return
        }
        self.presentAsSheet(self.viewControllerInformationLocalRemote!)
    }

    @IBAction func totinfo(_: NSButton) {
        guard self.checkforrsync() == false else { return }
        globalMainQueue.async { () -> Void in
            self.presentAsSheet(self.viewControllerRemoteInfo!)
        }
    }

    @IBAction func quickbackup(_: NSButton) {
        guard self.checkforrsync() == false else { return }
        self.openquickbackup()
    }

    @IBAction func edit(_: NSButton) {
        self.reset()
        guard self.index != nil else {
            self.info.stringValue = Infoexecute().info(num: 1)
            return
        }
        globalMainQueue.async { () -> Void in
            self.presentAsSheet(self.editViewController!)
        }
    }

    @IBAction func rsyncparams(_: NSButton) {
        self.reset()
        guard self.index != nil else {
            self.info.stringValue = Infoexecute().info(num: 1)
            return
        }
        globalMainQueue.async { () -> Void in
            self.presentAsSheet(self.viewControllerRsyncParams!)
        }
    }

    @IBAction func delete(_: NSButton) {
        guard self.index != nil else {
            self.info.stringValue = Infoexecute().info(num: 1)
            return
        }
        if let hiddenID = self.configurations?.gethiddenID(index: self.index!) {
            let question: String = NSLocalizedString("Delete selected task?", comment: "Execute")
            let text: String = NSLocalizedString("Cancel or Delete", comment: "Execute")
            let dialog: String = NSLocalizedString("Delete", comment: "Execute")
            let answer = Alerts.dialogOrCancel(question: question, text: text, dialog: dialog)
            if answer {
                // Delete Configurations and Schedules by hiddenID
                self.configurations!.deleteConfigurationsByhiddenID(hiddenID: hiddenID)
                self.schedules!.deletescheduleonetask(hiddenID: hiddenID)
                self.deselect()
                self.reloadtabledata()
                // Reset in tabSchedule
                self.reloadtable(vcontroller: .vctabschedule)
                self.reloadtable(vcontroller: .vcsnapshot)
            }
        }
        self.reset()
    }

    @IBAction func TCP(_: NSButton) {
        self.configurations?.tcpconnections = TCPconnections()
        self.configurations?.tcpconnections?.testAllremoteserverConnections()
        self.displayProfile()
    }

    // Presenting Information from Rsync
    @IBAction func information(_: NSButton) {
        globalMainQueue.async { () -> Void in
            self.presentAsSheet(self.viewControllerInformation!)
        }
    }

    // Abort button
    @IBAction func abort(_: NSButton) {
        globalMainQueue.async { () -> Void in
            self.abortOperations()
        }
    }

    // Userconfiguration button
    @IBAction func userconfiguration(_: NSButton) {
        globalMainQueue.async { () -> Void in
            self.presentAsSheet(self.viewControllerUserconfiguration!)
        }
    }

    // Selecting profiles
    @IBAction func profiles(_: NSButton) {
        if self.configurations?.tcpconnections?.connectionscheckcompleted ?? true {
            globalMainQueue.async { () -> Void in
                self.presentAsSheet(self.viewControllerProfile!)
            }
        } else {
            self.displayProfile()
        }
    }

    // Selecting About
    @IBAction func about(_: NSButton) {
        self.presentAsModalWindow(self.viewControllerAbout!)
    }

    // Selecting automatic backup
    @IBAction func automaticbackup(_: NSButton) {
        self.presentAsSheet(self.viewControllerEstimating!)
    }

    @IBAction func executetasknow(_: NSButton) {
        guard self.checkforrsync() == false else { return }
        guard self.index != nil else {
            self.info.stringValue = Infoexecute().info(num: 1)
            return
        }
        let task = self.configurations!.getConfigurations()[self.index!].task
        guard ViewControllerReference.shared.synctasks.contains(task) else {
            return
        }
        self.executetasknow = ExecuteTaskNow(index: self.index!)
    }

    // Function for display rsync command
    @IBAction func showrsynccommand(_: NSButton) {
        self.showrsynccommandmainview()
    }

    // Display correct rsync command in view
    func showrsynccommandmainview() {
        if let index = self.index {
            guard index <= self.configurations!.getConfigurations().count else { return }
            if self.backupdryrun.state == .on {
                self.rsyncCommand.stringValue = Displayrsyncpath(index: index, display: .synchronize).displayrsyncpath ?? ""
            } else if self.restoredryrun.state == .on {
                self.rsyncCommand.stringValue = Displayrsyncpath(index: index, display: .restore).displayrsyncpath ?? ""
            } else {
                self.rsyncCommand.stringValue = Displayrsyncpath(index: index, display: .verify).displayrsyncpath ?? ""
            }
        } else {
            self.rsyncCommand.stringValue = ""
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.mainTableView.delegate = self
        self.mainTableView.dataSource = self
        self.working.usesThreadedAnimation = true
        ViewControllerReference.shared.setvcref(viewcontroller: .vctabmain, nsviewcontroller: self)
        self.mainTableView.target = self
        self.mainTableView.doubleAction = #selector(ViewControllerMain.tableViewDoubleClick(sender:))
        self.backupdryrun.state = .on
        // configurations and schedules
        self.createandreloadconfigurations()
        self.createandreloadschedules()
        self.pathtorsyncosxschedbutton.toolTip = NSLocalizedString("The menu app", comment: "Execute")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if ViewControllerReference.shared.initialstart == 0 {
            self.view.window?.center()
            ViewControllerReference.shared.initialstart = 1
            _ = Checkfornewversion()
        }
        if self.configurations!.configurationsDataSourcecount() > 0 {
            globalMainQueue.async { () -> Void in
                self.mainTableView.reloadData()
            }
        }
        self.rsyncischanged()
        self.displayProfile()
        self.initpopupbutton(button: self.profilepopupbutton)
        self.delayWithSeconds(0.5) {
            self.menuappicons()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
    }

    func reset() {
        self.process = nil
        self.singletask = nil
        self.setNumbers(outputprocess: nil)
    }

    func menuappicons() {
        globalMainQueue.async { () -> Void in
            let running = Running()
            if running.rsyncOSXschedisrunning == true {
                self.menuappisrunning.image = #imageLiteral(resourceName: "green")
                self.info.stringValue = Infoexecute().info(num: 5)
                self.info.textColor = self.setcolor(nsviewcontroller: self, color: .green)
            } else {
                self.menuappisrunning.image = #imageLiteral(resourceName: "red")
            }
        }
    }

    // Execute tasks by double click in table
    @objc(tableViewDoubleClick:) func tableViewDoubleClick(sender _: AnyObject) {
        self.executeSingleTask()
    }

    // Single task can be activated by double click from table
    func executeSingleTask() {
        guard self.checkforrsync() == false else { return }
        guard self.index != nil else { return }
        let task = self.configurations!.getConfigurations()[self.index!].task
        guard ViewControllerReference.shared.synctasks.contains(task) else {
            self.info.stringValue = Infoexecute().info(num: 6)
            return
        }
        guard self.singletask != nil else {
            // Dry run
            self.singletask = SingleTask(index: self.index!)
            self.singletask?.executeSingleTask()
            return
        }
        // Real run
        self.singletask?.executeSingleTask()
    }

    // Execute batche tasks, only from main view
    @IBAction func executeBatch(_: NSButton) {
        guard self.checkforrsync() == false else { return }
        self.setNumbers(outputprocess: nil)
        self.deselect()
        globalMainQueue.async { () -> Void in
            self.presentAsSheet(self.viewControllerBatch!)
        }
    }

    // Function for setting profile
    func displayProfile() {
        weak var localprofileinfo: SetProfileinfo?
        weak var localprofileinfo2: SetProfileinfo?
        guard self.configurations?.tcpconnections?.connectionscheckcompleted ?? true else {
            self.profilInfo.stringValue = NSLocalizedString("Profile: please wait...", comment: "Execute")
            return
        }
        if let profile = self.configurations!.getProfile() {
            self.profilInfo.stringValue = NSLocalizedString("Profile:", comment: "Execute ") + " " + profile
            self.profilInfo.textColor = setcolor(nsviewcontroller: self, color: .white)
        } else {
            self.profilInfo.stringValue = NSLocalizedString("Profile:", comment: "Execute ") + " default"
            self.profilInfo.textColor = setcolor(nsviewcontroller: self, color: .green)
        }
        localprofileinfo = ViewControllerReference.shared.getvcref(viewcontroller: .vctabschedule) as? ViewControllerSchedule
        localprofileinfo2 = ViewControllerReference.shared.getvcref(viewcontroller: .vcnewconfigurations) as? ViewControllerNewConfigurations
        localprofileinfo?.setprofile(profile: self.profilInfo.stringValue, color: self.profilInfo.textColor!)
        localprofileinfo2?.setprofile(profile: self.profilInfo.stringValue, color: self.profilInfo.textColor!)
        self.showrsynccommandmainview()
    }

    func createandreloadschedules() {
        self.process = nil
        guard self.configurations != nil else {
            self.schedules = Schedules(profile: nil)
            return
        }
        if let profile = self.configurations!.getProfile() {
            self.schedules = nil
            self.schedules = Schedules(profile: profile)
        } else {
            self.schedules = nil
            self.schedules = Schedules(profile: nil)
        }
        self.schedulesortedandexpanded = ScheduleSortedAndExpand()
    }

    func createandreloadconfigurations() {
        guard self.configurations != nil else {
            self.configurations = Configurations(profile: nil)
            return
        }
        if let profile = self.configurations!.getProfile() {
            self.configurations = nil
            self.configurations = Configurations(profile: profile)
        } else {
            self.configurations = nil
            self.configurations = Configurations(profile: nil)
        }
        globalMainQueue.async { () -> Void in
            self.mainTableView.reloadData()
        }
        if let reloadDelegate = ViewControllerReference.shared.getvcref(viewcontroller: .vcallprofiles) as? ViewControllerAllProfiles {
            reloadDelegate.reloadtable()
        }
    }

    private func initpopupbutton(button: NSPopUpButton) {
        var profilestrings: [String]?
        profilestrings = CatalogProfile().getDirectorysStrings()
        profilestrings?.insert(NSLocalizedString("Default profile", comment: "default profile"), at: 0)
        button.removeAllItems()
        button.addItems(withTitles: profilestrings ?? [])
        button.selectItem(at: 0)
    }

    @IBAction func selectprofile(_: NSButton) {
        var profile = self.profilepopupbutton.titleOfSelectedItem
        if profile == NSLocalizedString("Default profile", comment: "default profile") {
            profile = nil
        }
        _ = Selectprofile(profile: profile)
    }
}
