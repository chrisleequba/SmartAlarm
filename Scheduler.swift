import Foundation
import UIKit
class Scheduler : AlarmSchedulerDelegate
{
    var alarmModel: Alarms = Alarms()
    func setupNotificationSettings() -> UIUserNotificationSettings {
        var snoozeEnabled: Bool = false
        if let n = UIApplication.shared.scheduledLocalNotifications {
            if let result = minFireDateWithIndex(notifications: n) {
                let i = result.1
                snoozeEnabled = alarmModel.alarms[i].snoozeEnabled
            }
        }
        let notificationTypes: UIUserNotificationType = [UIUserNotificationType.alert, UIUserNotificationType.sound]
        let stopAction = UIMutableUserNotificationAction()
        stopAction.identifier = Constants.stopIdentifier
        stopAction.title = "OK"
        stopAction.activationMode = UIUserNotificationActivationMode.background
        stopAction.isDestructive = false
        stopAction.isAuthenticationRequired = false
        let snoozeAction = UIMutableUserNotificationAction()
        snoozeAction.identifier = Constants.snoozeIdentifier
        snoozeAction.title = "Snooze"
        snoozeAction.activationMode = UIUserNotificationActivationMode.background
        snoozeAction.isDestructive = false
        snoozeAction.isAuthenticationRequired = false
        let actionsArray = snoozeEnabled ? [UIUserNotificationAction](arrayLiteral: snoozeAction, stopAction) : [UIUserNotificationAction](arrayLiteral: stopAction)
        let actionsArrayMinimal = snoozeEnabled ? [UIUserNotificationAction](arrayLiteral: snoozeAction, stopAction) : [UIUserNotificationAction](arrayLiteral: stopAction)
        let alarmCategory = UIMutableUserNotificationCategory()
        alarmCategory.identifier = "myAlarmCategory"
        alarmCategory.setActions(actionsArray, for: .default)
        alarmCategory.setActions(actionsArrayMinimal, for: .minimal)
        let categoriesForSettings = Set(arrayLiteral: alarmCategory)
        let newNotificationSettings = UIUserNotificationSettings(types: notificationTypes, categories: categoriesForSettings)
        UIApplication.shared.registerUserNotificationSettings(newNotificationSettings)
        return newNotificationSettings
    }
    private func correctDate(_ date: Date, onWeekdaysForNotify weekdays:[Int]) -> [Date]
    {
        var correctedDate: [Date] = [Date]()
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let now = Date()
        let flags: NSCalendar.Unit = [NSCalendar.Unit.weekday, NSCalendar.Unit.weekdayOrdinal, NSCalendar.Unit.day]
        let dateComponents = (calendar as NSCalendar).components(flags, from: date)
        let weekday:Int = dateComponents.weekday!
        if weekdays.isEmpty{
            if date < now {
                correctedDate.append((calendar as NSCalendar).date(byAdding: NSCalendar.Unit.day, value: 1, to: date, options:.matchStrictly)!)
            }
            else { 
                correctedDate.append(date)
            }
            return correctedDate
        }
        else {
            let daysInWeek = 7
            correctedDate.removeAll(keepingCapacity: true)
            for wd in weekdays {
                var wdDate: Date!
                if compare(weekday: wd, with: weekday) == .before {
                    wdDate =  (calendar as NSCalendar).date(byAdding: NSCalendar.Unit.day, value: wd+daysInWeek-weekday, to: date, options:.matchStrictly)!
                }
                else if compare(weekday: wd, with: weekday) == .same {
                    if date.compare(now) == ComparisonResult.orderedAscending {
                        wdDate = (calendar as NSCalendar).date(byAdding: NSCalendar.Unit.day, value: daysInWeek, to: date, options:.matchStrictly)!
                    }
                    else { 
                        wdDate = date
                    }
                }
                else { 
                    wdDate =  (calendar as NSCalendar).date(byAdding: NSCalendar.Unit.day, value: wd-weekday, to: date, options:.matchStrictly)!
                }
                wdDate = Scheduler.correctSecondComponent(date: wdDate, calendar: calendar)
                correctedDate.append(wdDate)
            }
            return correctedDate
        }
    }
    public static func correctSecondComponent(date: Date, calendar: Calendar = Calendar(identifier: Calendar.Identifier.gregorian))->Date {
        let second = calendar.component(.second, from: date)
        let d = (calendar as NSCalendar).date(byAdding: NSCalendar.Unit.second, value: -second, to: date, options:.matchStrictly)!
        return d
    }
    internal func setNotificationWithDate(_ date: Date, onWeekdaysForNotify weekdays:[Int], snoozeEnabled:Bool, onSnooze: Bool, soundName: String, index: Int) {
        if alarmModel.alarms.count > 0 {
            let AlarmNotification: UILocalNotification = UILocalNotification()
            AlarmNotification.alertBody = alarmModel.alarms[index].label
            AlarmNotification.alertAction = "Open App"
            AlarmNotification.category = "myAlarmCategory"
            AlarmNotification.soundName = soundName + ".mp3"
            AlarmNotification.timeZone = TimeZone.current
            let repeating: Bool = !weekdays.isEmpty
            AlarmNotification.userInfo = ["snooze" : snoozeEnabled, "index": index, "soundName": soundName, "repeating" : repeating]
            if !weekdays.isEmpty && !onSnooze{
                AlarmNotification.repeatInterval = NSCalendar.Unit.weekOfYear
            }
            let datesForNotification = correctDate(date, onWeekdaysForNotify:weekdays)
            syncAlarmModel()
            for d in datesForNotification {
                if onSnooze {
                    alarmModel.alarms[index].secretDate = Scheduler.correctSecondComponent(date: alarmModel.alarms[index].secretDate)
                }
                else {
                    alarmModel.alarms[index].secretDate = d
                }
                AlarmNotification.fireDate = d
                UIApplication.shared.scheduleLocalNotification(AlarmNotification)
            }
            setupNotificationSettings()
        }
    }
    func setNotificationForSnooze(snoozeMinute: Int, soundName: String, index: Int) {
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let now = Date()
        let snoozeTime = (calendar as NSCalendar).date(byAdding: NSCalendar.Unit.minute, value: snoozeMinute, to: now, options:.matchStrictly)!
        setNotificationWithDate(snoozeTime, onWeekdaysForNotify: [Int](), snoozeEnabled: true, onSnooze:true, soundName: soundName, index: index)
    }
    func reSchedule() {
        UIApplication.shared.cancelAllLocalNotifications()
        syncAlarmModel()
        for i in 0..<alarmModel.count{
            let alarm = alarmModel.alarms[i]
            if alarm.enabled {
                setNotificationWithDate(alarm.secretDate as Date, onWeekdaysForNotify: alarm.repeatWeekdays, snoozeEnabled: alarm.snoozeEnabled, onSnooze: false, soundName: alarm.mediaLabel, index: i)
            }
        }
    }
    func checkNotification() {
        alarmModel = Alarms()
        let notifications = UIApplication.shared.scheduledLocalNotifications
        if notifications!.isEmpty {
            for i in 0..<alarmModel.count {
                alarmModel.alarms[i].enabled = false
            }
        }
        else {
            for (i, alarm) in alarmModel.alarms.enumerated() {
                var isOutDated = true
                if alarm.onSnooze {
                    isOutDated = false
                }
                for n in notifications! {
                    if alarm.date >= n.fireDate! {
                        isOutDated = false
                    }
                }
                if isOutDated {
                    alarmModel.alarms[i].enabled = false
                }
            }
        }
    }
    private func syncAlarmModel() {
        alarmModel = Alarms()
    }
    private enum weekdaysComparisonResult {
        case before
        case same
        case after
    }
    private func compare(weekday w1: Int, with w2: Int) -> weekdaysComparisonResult {
        if w1 != 1 && w2 == 1 {return .before}
        else if w1 == w2 {return .same}
        else {return .after}
    }
    private func minFireDateWithIndex(notifications: [UILocalNotification]) -> (Date, Int)? {
        if notifications.isEmpty {
            return nil
        }
        var minIndex = -1
        var minDate: Date = notifications.first!.fireDate!
        for n in notifications {
            let index = n.userInfo!["index"] as! Int
            if(n.fireDate! <= minDate) {
                minDate = n.fireDate!
                minIndex = index
            }
        }
        return (minDate, minIndex)
    }
}
