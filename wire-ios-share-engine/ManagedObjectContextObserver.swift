//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//


import ZMCDataModel


typealias ObserverToken = UInt


extension Sendable where Self: NSManagedObject {
    func addObserver(observer: SendableObserver) -> SendableObserverToken {
        guard let globalObserver = GlobalSendableObserver.sharedObserver else { assert(false, "Global observer not set up") }
        return globalObserver.addObserver(self, observer: observer)
    }
    
    func removeObserver(token: SendableObserverToken) {
        guard let globalObserver = GlobalSendableObserver.sharedObserver else { return }
        globalObserver.removeObserver(token)
    }
}

public class GlobalSendableObserver {
    
    var observedObjects = [SendableObserverToken: Sendable]()
    var deliveryStateBySendable = [Int: ZMDeliveryState]()
    var observers = [SendableObserverToken: SendableObserver]()
    private var token: NSObjectProtocol?
    var tokenCount: UInt = 0
    
    static var sharedObserver: GlobalSendableObserver? = nil
    
    public static func setupGlobalObserver(context: NSManagedObjectContext) {
        sharedObserver = GlobalSendableObserver(context: context)
    }
    
    private init(context: NSManagedObjectContext) {
        token = NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: context, queue: .mainQueue(), usingBlock: objectsDidChange)
    }
    
    deinit {
        guard let token = token else { return }
        NSNotificationCenter.defaultCenter().removeObserver(token)
    }
    
    func addObserver<T: Sendable where T: NSManagedObject>(object: T, observer: SendableObserver) -> SendableObserverToken {
        tokenCount += 1
        let token = tokenCount
        
        observedObjects[token] = object
        observers[token] = observer
        deliveryStateBySendable[object.hashValue] = object.deliveryState
        return token
    }
    
    func removeObserver(token: UInt) {
        observers[token] = nil
        observedObjects[token] = nil
    }
    
    private func objectsDidChange(note: NSNotification) {
        guard let userInfo = note.userInfo else { return }
        var changes = Set<NSManagedObject>()
        if let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> { changes.unionInPlace(updates) }
        if let deletions = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> { changes.unionInPlace(deletions) }
        if let inserted = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> { changes.unionInPlace(inserted) }
        
        guard changes.count > 0 else { return }
        processChanges(changes)
    }
    
    private func processChanges(changes: Set<NSManagedObject>) {
        observedObjects.forEach { token, sendable in
            guard let object = sendable as? NSManagedObject where changes.contains(object) else { return }
            guard let observer = observers[token] else { return }
            let (previous, current) = (deliveryStateBySendable[object.hashValue], sendable.deliveryState)
            guard previous != current else { return }
            deliveryStateBySendable[object.hashValue] = current
            observer.onDeliveryChanged()
        }
        
    }
}
