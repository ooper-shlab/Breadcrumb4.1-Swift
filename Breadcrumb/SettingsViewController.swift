//
//  SettingsViewController.swift
//  Breadcrumb
//
//  Translated by OOPer in cooperation with shlab.jp on 2014/12/19.
//
//
/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:

  NSUserDefaults global keys for reading/writing user defaults

 */

// value is a BOOL
let TrackLocationInBackgroundPrefsKey  = "TrackLocationInBackgroundPrefsKey"

// value is a CLLocationAccuracy (double)
let LocationTrackingAccuracyPrefsKey   = "LocationTrackingAccuracyPrefsKey"

// value is a BOOL
let PlaySoundOnLocationUpdatePrefsKey  = "PlaySoundOnLocationUpdatePrefsKey"


//MARK: -

import MapKit

// table cell identifiers
private let SwitchOptionCellID = "SwitchOptionTableViewCell" // generic switch cell
private let PickerOptionCellID = "PickerOptionTableViewCell" // generic picker cell


//MARK: -

@objc(AccuracyPickerOption)
class AccuracyPickerOption: NSObject {
    
    var headline: String
    var details: String?
    var defaultsKey: String
    
    init(headline description: String, details: String?, defaultsKey: String) {
        
        self.headline = description
        self.details = details
        self.defaultsKey = defaultsKey
        
    }
    
}


//MARK: -

@objc(SwitchOption)
private class SwitchOption: NSObject {
    
    var headline: String
    var details: String
    var defaultsKey: String
    
    init(headline description: String, details: String, defaultsKey: String) {
        
        self.headline = description
        self.details = details
        self.defaultsKey = defaultsKey
        
    }
    
}


//MARK: -

@objc(SwitchOptionTableViewCell)
private class SwitchOptionTableViewCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailsLabel: UILabel!
    @IBOutlet weak var switchControl: UISwitch!
    var defaultsKey: String!
    
    
    //MARK: -
    
    func configureWithOptiuons(_ options: SwitchOption) {
        self.titleLabel?.text = options.headline
        self.defaultsKey = options.defaultsKey
        self.detailsLabel?.text = options.details
        self.switchControl.isOn = UserDefaults.standard.bool(forKey: self.defaultsKey)
    }
    
    // called from "toggleSwitch" - user changes a setting that uses UISwitch to change its settings
    
    @IBAction func updatePreferencesFromView(_: AnyObject) {
        UserDefaults.standard.set(self.switchControl.isOn, forKey: self.defaultsKey)
    }
    
    @IBAction func toggleSwitch(_: AnyObject) {
        // one of the UISwitch-based preference has changed
        let aSwitch: UISwitch = self.switchControl
        let newState = aSwitch.isOn
        aSwitch.setOn(newState, animated: true)
        self.updatePreferencesFromView(aSwitch)
    }
    
}


//MARK: -

@objc(PickerOptionTableViewCell)
class PickerOptionTableViewCell: UITableViewCell, UIPickerViewDataSource, UIPickerViewDelegate {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var detailsLabel: UILabel!
    @IBOutlet var pickerView: UIPickerView!
    var defaultsKey: String!
    
    
    //MARK: -
    
    func configureWithOptions(_ options: AccuracyPickerOption) {
        self.titleLabel?.text = options.headline
        self.defaultsKey = options.defaultsKey
        self.detailsLabel?.text = options.details
        
        // set the picker to match the value of the default CLLocationAccuracy
        let accuracyNum = UserDefaults.standard.value(forKey: self.defaultsKey) as! NSNumber
        let accuracy = CLLocationAccuracy(accuracyNum.doubleValue)
        
        var row = 0
        switch accuracy {
        case kCLLocationAccuracyBestForNavigation:
            row = 0
        case kCLLocationAccuracyBest:
            row = 1
        case kCLLocationAccuracyNearestTenMeters:
            row = 2
        case kCLLocationAccuracyHundredMeters:
            row = 3
        case kCLLocationAccuracyKilometer:
            row = 4
        case kCLLocationAccuracyThreeKilometers:
            row = 5
        default:
            break
        }
        
        self.pickerView.selectRow(row, inComponent:0, animated: false)
    }
    
    // returns the number of 'columns' to display on the picker
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // returns the number of rows in the first component of the picker
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 6
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 18.0
    }
    
    
    func accuracyTitleAndValueForRow(_ row: Int) -> (title: String, value: CLLocationAccuracy) {
        var title = ""
        var accuracyValue: CLLocationAccuracy = -1
        
        switch row {
        case 0:
            title = "kCLLocationAccuracyBestForNavigation"
            accuracyValue = kCLLocationAccuracyBestForNavigation
        case 1:
            title = "kCLLocationAccuracyBest"
            accuracyValue = kCLLocationAccuracyBest
        case 2:
            title = "kCLLocationAccuracyNearestTenMeters"
            accuracyValue = kCLLocationAccuracyNearestTenMeters
        case 3:
            title = "kCLLocationAccuracyHundredMeters"
            accuracyValue = kCLLocationAccuracyHundredMeters
        case 4:
            title = "kCLLocationAccuracyKilometer"
            accuracyValue = kCLLocationAccuracyKilometer
        case 5:
            title = "kCLLocationAccuracyThreeKilometers"
            accuracyValue = kCLLocationAccuracyThreeKilometers
        default:
            break
        }
        
        return (title, accuracyValue)
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        var customView: UILabel! = view as! UILabel!
        if customView == nil {
            customView = UILabel(frame: CGRect())
        }
        
        // find the accuracy title for the given row
        let result = self.accuracyTitleAndValueForRow(row)
        let title = result.title
        
        let attrString = NSMutableAttributedString(string: title)
        let font = UIFont.systemFont(ofSize: 12)
        attrString.addAttribute(NSFontAttributeName, value: font, range: NSMakeRange(0, title.utf16.count))
        
        customView.attributedText = attrString
        customView.textAlignment = .center
        
        return customView
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // find the accuracy value from the selected row
        let result = self.accuracyTitleAndValueForRow(row)
        let accuracy = result.value
        
        // this will cause an NSNotification to occur (NSUserDefaultsDidChangeNotification)
        // ultimately calling BreadcrumbViewController - (void)settingsDidChange:(NSNotification *)notification
        //
        let defaults = UserDefaults.standard
        defaults.set(Int(accuracy), forKey: LocationTrackingAccuracyPrefsKey)
    }
    
}


//MARK: -

@objc(SettingsViewController)
class SettingsViewController: UITableViewController {
    
    private var settings: [AnyObject]!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.settings = [
            SwitchOption(headline: NSLocalizedString("Background Updates:", comment: "Label for switch that enables and disables background updates"),
                details: NSLocalizedString("Turn on/off tracking current location while suspended.", comment: "Description for switch that enables and disables background updates"),
                defaultsKey: TrackLocationInBackgroundPrefsKey),
            
            AccuracyPickerOption(headline: "Accurary",
                details: NSLocalizedString("Set level of accuracy when tracking your location.", comment: "Description for accuracy"),
                defaultsKey: LocationTrackingAccuracyPrefsKey),
            
            SwitchOption(headline: "Audio Feedback",
                details: "Play a sound when a new location update is received.",
                defaultsKey: PlaySoundOnLocationUpdatePrefsKey),
        ]
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var cellHeight: CGFloat = 0.0
        
        let option: AnyObject = self.settings[indexPath.row]
        
        if option is AccuracyPickerOption {
            cellHeight = 213.00
        }
        if option is SwitchOption {
            cellHeight = 105.0
        }
        return cellHeight
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.settings.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let option: AnyObject = self.settings[indexPath.row]
        
        var cell: UITableViewCell! = nil
        
        if option is AccuracyPickerOption {
            let pickerCell = tableView.dequeueReusableCell(withIdentifier: PickerOptionCellID) as! PickerOptionTableViewCell
            
            let pickerOption = option as! AccuracyPickerOption
            pickerCell.configureWithOptions(pickerOption)
            cell = pickerCell
        }
        if option is SwitchOption {
            let switchCell = tableView.dequeueReusableCell(withIdentifier: SwitchOptionCellID) as! SwitchOptionTableViewCell
            
            let switchOption = option as! SwitchOption
            switchCell.configureWithOptiuons(switchOption)
            cell = switchCell
        }
        
        return cell
    }
    
}
