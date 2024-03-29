import UIKit
import FontAwesome_swift
class MainAlarmViewController: UITableViewController {
	@IBOutlet var menuButton: UIBarButtonItem!
	@IBOutlet var addButton: UIBarButtonItem!
    var alarmDelegate: AlarmApplicationDelegate = AppDelegate()
    var alarmScheduler: AlarmSchedulerDelegate = Scheduler()
    var alarmModel: Alarms = Alarms()
    override func viewDidLoad() {
        super.viewDidLoad()
        alarmScheduler.checkNotification()
        tableView.allowsSelectionDuringEditing = true
		Utils.createFontAwesomeBarButton(button: addButton, icon: .plus, style: .solid)
		Utils.createFontAwesomeBarButton(button: menuButton, icon: .bars, style: .solid)
		Utils.insertGradientIntoTableView(viewController: self, tableView: tableView)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        alarmModel = Alarms()
        tableView.reloadData()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
	override var prefersStatusBarHidden: Bool {
		return true
	}
	@IBAction func menuButtonPressed(_ sender: AnyObject) {
		Utils.presentView(self, viewName: Constants.Views.SETTINGS_NAV_CONTROLLER)
	}
	public override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 60.0
	}
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let label = UILabel()
		label.backgroundColor = UIColor.clear
		label.textColor = UIColor.white
		label.lineBreakMode = .byWordWrapping
		label.numberOfLines = 0
		label.textAlignment = .center
		label.font = UIFont.GothamProRegular(size: 10)
		label.text = "All alarms will trigger 5-15 minutes earlier than the time they are scheduled for 😊"
		return label
	}
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return alarmModel.count
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            performSegue(withIdentifier: Constants.editSegueIdentifier, sender: SegueInfo(curCellIndex: indexPath.row, isEditMode: true, label: alarmModel.alarms[indexPath.row].label, selectedSound: alarmModel.alarms[indexPath.row].mediaLabel, mediaID: alarmModel.alarms[indexPath.row].mediaID, repeatWeekdays: alarmModel.alarms[indexPath.row].repeatWeekdays, enabled: alarmModel.alarms[indexPath.row].enabled, snoozeEnabled: alarmModel.alarms[indexPath.row].snoozeEnabled))
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: Constants.alarmCellIdentifier)
        if (cell == nil) {
            cell = UITableViewCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: Constants.alarmCellIdentifier)
        }
		cell!.backgroundColor = UIColor.clear
		cell!.textLabel?.textColor = UIColor.white
		cell!.detailTextLabel?.textColor = UIColor.white
		cell!.detailTextLabel?.font = UIFont.GothamProRegular(size: 16.0)
		cell!.selectionStyle = .none
        cell!.tag = indexPath.row
        let alarm: Alarm = alarmModel.alarms[indexPath.row]
		let amAttr: [NSAttributedStringKey : Any] = [NSAttributedStringKey(rawValue: NSAttributedStringKey.font.rawValue) : UIFont.GothamProMedium(size: 25.0)!]
        let str = NSMutableAttributedString(string: alarm.formattedTime, attributes: amAttr)
		let timeAttr: [NSAttributedStringKey : Any] = [NSAttributedStringKey(rawValue: NSAttributedStringKey.font.rawValue) : UIFont.GothamProMedium(size: 40.0)!]
        str.addAttributes(timeAttr, range: NSMakeRange(0, str.length-5))
		cell!.textLabel?.attributedText = str
		cell!.detailTextLabel?.text = alarm.label + ", " + WeekdaysViewController.repeatText(weekdays: alarm.repeatWeekdays)
        let switchButton = UISwitch(frame: CGRect())
        switchButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9);
        switchButton.tag = indexPath.row
        switchButton.addTarget(self, action: #selector(MainAlarmViewController.switchTapped(_:)), for: UIControlEvents.valueChanged)
        if alarm.enabled {
            cell!.textLabel?.alpha = 1.0
            cell!.detailTextLabel?.alpha = 1.0
            switchButton.setOn(true, animated: false)
			switchButton.onTintColor = UIColor(hex: Constants.Purchases.Colors[Constants.Purchases.SUNRISE_THEME]![1])
        }
		else {
            cell!.textLabel?.alpha = 0.5
            cell!.detailTextLabel?.alpha = 0.5
        }
        cell!.accessoryView = switchButton
        return cell!
    }
    @IBAction func switchTapped(_ sender: UISwitch) {
        let index = sender.tag
        alarmModel.alarms[index].enabled = sender.isOn
        if sender.isOn {
            alarmScheduler.setNotificationWithDate(alarmModel.alarms[index].secretDate, onWeekdaysForNotify: alarmModel.alarms[index].repeatWeekdays, snoozeEnabled: alarmModel.alarms[index].snoozeEnabled, onSnooze: false, soundName: alarmModel.alarms[index].mediaLabel, index: index)
            tableView.reloadData()
        }
        else {
            alarmScheduler.reSchedule()
            tableView.reloadData()
        }
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let index = indexPath.row
            alarmModel.alarms.remove(at: index)
            let cells = tableView.visibleCells
            for cell in cells {
                let sw = cell.accessoryView as! UISwitch
                if sw.tag > index {
                    sw.tag -= 1
                }
            }
            tableView.deleteRows(at: [indexPath], with: .fade)
            alarmScheduler.reSchedule()
        }   
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let dist = segue.destination as! UINavigationController
        let addEditController = dist.topViewController as! AlarmAddEditViewController
        if segue.identifier == Constants.addSegueIdentifier {
            addEditController.navigationItem.title = "Add Alarm"
            addEditController.segueInfo = SegueInfo(curCellIndex: alarmModel.count, isEditMode: false, label: "Alarm", selectedSound: "Bell", mediaID: "", repeatWeekdays: [Date().dayNumberOfWeek()!], enabled: false, snoozeEnabled: false)
        }
        else if segue.identifier == Constants.editSegueIdentifier {
            addEditController.navigationItem.title = "Edit Alarm"
            addEditController.segueInfo = sender as! SegueInfo
        }
    }
    @IBAction func unwindFromAddEditAlarmView(_ segue: UIStoryboardSegue) {
        isEditing = false
    }
    public func changeSwitchButtonState(index: Int) {
        alarmModel = Alarms()
        if alarmModel.alarms[index].repeatWeekdays.isEmpty {
            alarmModel.alarms[index].enabled = false
        }
        let cells = tableView.visibleCells
        for cell in cells {
            if cell.tag == index {
                let sw = cell.accessoryView as! UISwitch
                if alarmModel.alarms[index].repeatWeekdays.isEmpty {
                    sw.setOn(false, animated: false)
                    cell.backgroundColor = UIColor.groupTableViewBackground
                    cell.textLabel?.alpha = 0.5
                    cell.detailTextLabel?.alpha = 0.5
                }
            }
        }
    }
}
