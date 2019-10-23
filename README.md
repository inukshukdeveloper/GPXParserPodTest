**Overview**

This test harness demonstrates usage of the GPXXMLParser swift framework.  The GPXXMLParser framework parses GPX XML files and generates a tree of GPX objects.  It is a universal framework suitable for both iOS devices and simulators.

The following classes are currently exposed in the API and is not exhaustive of the current GPX schema.  If demand for more coverage presents itself, more schema coverage can be added.

**Installing the Parser**

The parser is available as a cocoa pod, so to install, first install cocoa pods and then add the following to Podfile:

pod &#39;GPXXMLParser&#39;

**Class Reference**

Class GPXXMLParser

**Public Member Functions**

     public init(url: URL)

**Properties**

     public var tracks: [GPXTrack]

     public var routes: [GPXRoute]

     public var metadata: GPXMetadata

     public var waypoints: [GPXWaypoint]

Class GPXBaseElement

**Public Member Functions**

**Properties**

     public var elementName: String

     public var value: String

Class GPXMetaData: GPXBaseElement

**Public Member Functions**

     name() -> String?

     desc() -> String?

     keywords() -> String?

     time() -> Date?

     author() -> GPXAuthor?

     copyright() -> GPXCopyright?

     extensions() -> GPXBaseElement?

     link() -> GPXLink?

**Properties**

Class GPXLink: GPXBaseElement

**Public Member Functions**

**Properties**

Class GPXBounds

**Public Member Functions**

**Properties**

      var maxlat: String

      var maxlon: String

      var minlat: String

      var minlon: String

Class GPXPoint: GPXBaseElement

**Public Member Functions**

      time() -> Date?

      ele() -> String?

**Properties**

     var lat: String

     var lon: String

Class GPXWaypoint: GPXPoint

**Public Member Functions**

     name() -> String?

     cmt() -> String?

     desc() -> String?

     ageofdgpsdata() -> String?

     dgpsid() -> String?

     fix() -> String?

     geoidHeight() -> String?

     horizontalDilution() -> String?

     verticalDilution() -> String?

     link() -> GPXLink?

     magneticvariation() -> String?

     positionDilution() -> String?

     satellites() -> String?

     source() -> String?

     sym() -> String?

     type() -> String?

     extensions() -> GPXExtensions?

**Properties**

Class GPXCopyright

**Public Member Functions**

     license() -> GPXLicense?

     year() -> GPXYear?

     author() -> GPXAuthor?

**Properties**



Class GPXLicense: GPXBaseElement

**Public Member Functions**

**Properties**

Class GPXYear: GPXBaseElement

**Public Member Functions**

Properties



Class GPXExtensions: GPXBaseElement

**Public Member Functions**

     extensions() -> [GPXBaseElement]?

**Properties**



Class GPXPerson: GPXBaseElement

**Public Member Functions**

     name() -> String?

     email() -> GPXEmail?

     link() -> GPXLink?

**Properties**



Class GPXAuthor: GPXPerson

**Public Member Functions**

**Properties**



Class GPXTrack: GPXBaseElement

Public Member Functions

     desc() -> String?

     name() -> String?

     comment() -> String?

     link() -> [GPXLink]?

     source() -> GPXBaseElement?

     number() -> String?

     type() -> String?

     extensions() -> GPXExtensions?

Properties

     trksegments: [GPXTrackSeg]



Class GPXTrackSeg: GPXBaseElement

**Public Member Functions**

     extensions() -> GPXExtension?

**Properties**

     var trackpoints: [GPXTrackPoint]



Class GPXTrackPoint: GPXWaypoint

**Public Member Functions**

**Properties**



Class GPXRoute: GPXBaseElement

**Public Member Functions**

     desc() -> String?

     name() -> String?

     comment() -> String?

     link() -> [GPXLink]?

     source() -> GPXBaseElement?

     number() -> String?

     type() -> String?

     extensions() -> GPXExtensions?

**Properties**

     var routepoints: [GPXRoutePoint]



Class GPXRoutePoint: GPXWaypoint

**Public Member Functions**

**Properties**
