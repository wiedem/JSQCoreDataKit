//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://www.jessesquires.com/JSQCoreDataKit
//
//
//  GitHub
//  https://github.com/jessesquires/JSQCoreDataKit
//
//
//  License
//  Copyright © 2015 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

import CoreData
import Foundation


/**
 An instance of `CoreDataStackFactory` is responsible for creating instances of `CoreDataStack`.

 Because the adding of the persistent store to the persistent store coordinator during initialization
 of a `CoreDataStack` can take an unknown amount of time, you should not perform this operation on the main queue.

 See this [guide](https://developer.apple.com/library/prerelease/ios/documentation/Cocoa/Conceptual/CoreData/IntegratingCoreData.html#//apple_ref/doc/uid/TP40001075-CH9-SW1) for more details.

 - warning: You should not create instances of `CoreDataStack` directly. Use a `CoreDataStackFactory` instead.
 */
public struct CoreDataStackFactory: CustomStringConvertible, Equatable {

    // MARK: Properties

    /// The model for the stack that the factory produces.
    public let model: CoreDataModel

    /**
     A dictionary that specifies options for the store that the factory produces.
     The default value is `DefaultStoreOptions`.
     */
    public let options: PersistentStoreOptions?


    // MARK: Initialization

    /**
     Constructs a new `CoreDataStackFactory` instance with the specified `model` and `options`.

     - parameter model:   The model describing the stack.
     - parameter options: Options for the persistent store.

     - returns: A new `CoreDataStackFactory` instance.
     */
    public init(model: CoreDataModel, options: PersistentStoreOptions? = defaultStoreOptions) {
        self.model = model
        self.options = options
    }


    // MARK: Creating a stack

    /**
     Initializes a new `CoreDataStack` instance using the factory's `model` and `options`.

     - warning: The persistent stores will be added asynchronously which means that the
     returned stack cannot be used for write operations until the completion callback has
     been called.

     - parameter completion: The closure to be called once initialization is complete and
     after all stores have been loaded successfully.
     */
    public func createStack(completion: (result: StackResult) -> Void) -> CoreDataStack {

        let storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model.managedObjectModel)

        let backgroundContext = self.createContext(.PrivateQueueConcurrencyType, name: "background")
        backgroundContext.persistentStoreCoordinator = storeCoordinator

        let mainContext = self.createContext(.MainQueueConcurrencyType, name: "main")
        mainContext.persistentStoreCoordinator = storeCoordinator

        let stack = CoreDataStack(model: self.model,
                                  mainContext: mainContext,
                                  backgroundContext: backgroundContext,
                                  storeCoordinator: storeCoordinator)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            do {
                try storeCoordinator.addPersistentStoreWithType(self.model.storeType.type,
                                                                configuration: nil,
                                                                URL: self.model.storeURL,
                                                                options: self.options)
            } catch {
                dispatch_async(dispatch_get_main_queue(), {
                    completion(result: .failure(error as NSError))
                })
            }

            dispatch_async(dispatch_get_main_queue(), {
                completion(result: .success(stack))
            })
        }

        return stack
    }


    // MARK: Private

    private func createContext(
        concurrencyType: NSManagedObjectContextConcurrencyType,
        name: String) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: concurrencyType)
        context.mergePolicy = NSMergePolicy(mergeType: .MergeByPropertyStoreTrumpMergePolicyType)

        let contextName = "JSQCoreDataKit.CoreDataStack.context."
        context.name = contextName + name

        return context
    }


    // MARK: CustomStringConvertible
    
    /// :nodoc:
    public var description: String {
        get {
            return "<\(CoreDataStackFactory.self): model=\(model.name); options=\(options)>"
        }
    }
}
