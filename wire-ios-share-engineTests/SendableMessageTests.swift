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


import XCTest
import ZMCDataModel
@testable import WireShareEngine

class FakeObserver: SendableObserver {

    var deliveryChangedCount = 0
    
    func onDeliveryChanged() {
        deliveryChangedCount += 1
    }
    
    func resetDeliveryChangeCount() {
        deliveryChangedCount = 0
    }

}

struct FakeAuthenticationStatus: AuthenticationStatusProvider {
    var state: AuthenticationState = .Authenticated
}

class SendableMessageTests: BaseSharingSessionTests {

    var sut: Sendable!
    
    override func setUp() {
        super.setUp()
        let conversation = ZMConversation.insertNewObjectInManagedObjectContext(moc)
        GlobalSendableObserver.setupGlobalObserver(moc)
        conversation.remoteIdentifier = NSUUID()
        sut = conversation.appendTextMessage("Text Message")
        moc.saveOrRollback()
    }

    func testThatItNotifiesTheObserverWhenTheDeliveryStateChanges() {
        // given
        let observer = FakeObserver()
        let token = sut.registerObserverToken(observer)
        XCTAssertNotNil(token)
        
        // when
        (sut as! ZMMessage).markAsSent()
        moc.saveOrRollback()

        // then
        XCTAssertEqual(observer.deliveryChangedCount, 1)
        sut.remove(token)
    }
    
    func testThatItDoesNotNotifyTheObserverWhenTheDeliveryStateDoesNotChange() {
        // given
        let observer = FakeObserver()
        let token = sut.registerObserverToken(observer)
        XCTAssertNotNil(token)
        
        // when
        (sut as! ZMMessage).markAsSent()
        moc.saveOrRollback()
        observer.resetDeliveryChangeCount()
        
        (sut as! ZMMessage).markAsSent()
        moc.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.deliveryChangedCount, 0)
        sut.remove(token)
    }

}
