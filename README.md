# CoreDataDitto

[![CI Status](https://img.shields.io/travis/2183729/CoreDataDitto.svg?style=flat)](https://travis-ci.org/2183729/CoreDataDitto)
[![Version](https://img.shields.io/cocoapods/v/CoreDataDitto.svg?style=flat)](https://cocoapods.org/pods/CoreDataDitto)
[![License](https://img.shields.io/cocoapods/l/CoreDataDitto.svg?style=flat)](https://cocoapods.org/pods/CoreDataDitto)
[![Platform](https://img.shields.io/cocoapods/p/CoreDataDitto.svg?style=flat)](https://cocoapods.org/pods/CoreDataDitto)

This is an experimental library that watches CoreData changes and reflects them into Ditto. Any Ditto `.update` observable events are insert, updated, or removed from CoreData
## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.
(Currently the example is useless, please see the XCTest cases instead!)

## Requirements

1. Clone this repo
2. At the root of this repo run `touch license_token.txt` and paste in a valid license token.
3. Paste in a valid license token.
## Installation

CoreDataDitto is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'CoreDataDitto'
```

## Architecture

CoreDataDitto will attempt to sync changes from a CoreData entity using a `NSFetchResult` with a corresponding `DittoPendingCursorOperation`. For example, if you have a `MenuItem` model from CoreData, you'll want to sync it with the `menuItem` Ditto collection.

1. When you call `coreDataDitto.startSync()`, first it'll loop through all CoreData objects and force Ditto match it. Any ditto documents that are not in core data will be removed.
2. Then it will start a liveQuery to observe the `DittoPendingCursorOperation` and reflect ditto `.update` changes into CoreDataEntities
3. `CoreDataDitto` internally uses a `NSFetchResultsController` to observe edits to CoreData objects and will translate them into Ditto `insert`, `update`, and `remove` operations


## Author

2183729, max@ditto.live

## License

CoreDataDitto is available under the MIT license. See the LICENSE file for more info.
