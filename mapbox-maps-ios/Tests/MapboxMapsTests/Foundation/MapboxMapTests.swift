import XCTest
@_spi(Experimental) @_spi(Package) @testable import MapboxMaps
@_implementationOnly import MapboxCoreMaps_Private

final class MapboxMapTests: XCTestCase {

    var mapClient: MockMapClient!
    var mapInitOptions: MapInitOptions!
    var events: MapEvents!
    var mapboxMap: MapboxMap!

    // We don't store fooSubject strongly to test that MapEvents stores the subjects it created.
    weak private var fooGenericSubject: SignalSubject<GenericEvent>?

    override func setUp() {
        super.setUp()
        let size = CGSize(width: 100, height: 200)
        events = MapEvents(makeGenericSubject: { [weak self] eventName in
            let s = SignalSubject<GenericEvent>()
            if eventName == "foo" {
                if let fooSubject = self?.fooGenericSubject {
                    return fooSubject
                } else {
                    self?.fooGenericSubject = s
                    return s
                }
            }
            return s
        })
        mapClient = MockMapClient()
        mapClient.getMetalViewStub.defaultReturnValue = MTKView(frame: CGRect(origin: .zero, size: size))
        mapInitOptions = MapInitOptions(mapOptions: MapOptions(size: size))

        let map = Map(client: mapClient, mapOptions: mapInitOptions.mapOptions)
        mapboxMap = MapboxMap(map: map, events: events, styleSourceManager: MockStyleSourceManager())
    }

    override func tearDown() {
        mapboxMap = nil
        mapInitOptions = nil
        mapClient = nil
        events = nil
        fooGenericSubject = nil
        super.tearDown()
    }

    func testInitializationOfMapOptions() {
        let expectedMapOptions = MapOptions(
            __contextMode: nil,
            constrainMode: NSNumber(value: mapInitOptions.mapOptions.constrainMode.rawValue),
            viewportMode: mapInitOptions.mapOptions.viewportMode.map { NSNumber(value: $0.rawValue) },
            orientation: NSNumber(value: mapInitOptions.mapOptions.orientation.rawValue),
            crossSourceCollisions: mapInitOptions.mapOptions.crossSourceCollisions.NSNumber,
            optimizeForTerrain: mapInitOptions.mapOptions.optimizeForTerrain.NSNumber,
            size: mapInitOptions.mapOptions.size.map(Size.init),
            pixelRatio: mapInitOptions.mapOptions.pixelRatio,
            glyphsRasterizationOptions: nil) // __map.getOptions() always returns nil for glyphsRasterizationOptions

        let actualMapOptions = mapboxMap.options

        XCTAssertEqual(actualMapOptions, expectedMapOptions)
    }

    func testInitializationInvokesMapClientGetMetalView() {
        XCTAssertEqual(mapClient.getMetalViewStub.invocations.count, 1)
    }

    func testSetSize() {
        let expectedSize = CGSize(
            width: .random(in: 100...1000),
            height: .random(in: 100...1000))

        mapboxMap.size = expectedSize

        XCTAssertEqual(CGSize(mapboxMap.__testingMap.getSize()), expectedSize)
    }

    func testGetSize() {
        let expectedSize = Size(
            width: .random(in: 100...1000),
            height: .random(in: 100...1000))
        mapboxMap.__testingMap.setSizeFor(expectedSize)

        let actualSize = mapboxMap.size

        XCTAssertEqual(actualSize, CGSize(expectedSize))
    }

    func testGetRenderWorldCopies() {
        let renderWorldCopies = Bool.random()
        mapboxMap.__testingMap.setRenderWorldCopiesForRenderWorldCopies(renderWorldCopies)
        XCTAssertEqual(mapboxMap.shouldRenderWorldCopies, renderWorldCopies)
    }

    func testSetRenderWorldCopies() {
        let renderWorldCopies = Bool.random()
        mapboxMap.shouldRenderWorldCopies = renderWorldCopies
        XCTAssertEqual(mapboxMap.__testingMap.getRenderWorldCopies(), renderWorldCopies)
    }

    func testGetCameraOptions() {
        XCTAssertEqual(mapboxMap.cameraState, CameraState(mapboxMap.__testingMap.getCameraState()))
    }

    func testCameraForCoordinateArray() {
        // A 1:1 square
        let southwest = CLLocationCoordinate2DMake(0, 0)
        let northwest = CLLocationCoordinate2DMake(4, 0)
        let northeast = CLLocationCoordinate2DMake(4, 4)
        let southeast = CLLocationCoordinate2DMake(0, 4)

        let latitudeDelta =  northeast.latitude - southeast.latitude
        let longitudeDelta = southeast.longitude - southwest.longitude

        let expectedCenter = CLLocationCoordinate2DMake(northeast.latitude - (latitudeDelta / 2),
                                                        southeast.longitude - (longitudeDelta / 2))

        let camera = mapboxMap.camera(
            for: [
                southwest,
                northwest,
                northeast,
                southeast
            ],
            padding: .zero,
            bearing: 0,
            pitch: 0)

        XCTAssertEqual(expectedCenter.latitude, camera.center!.latitude, accuracy: 0.25)
        XCTAssertEqual(expectedCenter.longitude, camera.center!.longitude, accuracy: 0.25)
        XCTAssertEqual(camera.bearing, 0)
        XCTAssertEqual(camera.padding, .zero)
        XCTAssertEqual(camera.pitch, 0)
    }

    func testCameraForGeometry() {
        // A 1:1 square
        let southwest = CLLocationCoordinate2DMake(0, 0)
        let northwest = CLLocationCoordinate2DMake(4, 0)
        let northeast = CLLocationCoordinate2DMake(4, 4)
        let southeast = CLLocationCoordinate2DMake(0, 4)

        let coordinates = [
            southwest,
            northwest,
            northeast,
            southeast,
        ]

        let latitudeDelta =  northeast.latitude - southeast.latitude
        let longitudeDelta = southeast.longitude - southwest.longitude

        let expectedCenter = CLLocationCoordinate2DMake(northeast.latitude - (latitudeDelta / 2),
                                                        southeast.longitude - (longitudeDelta / 2))

        let geometry = Geometry.polygon(Polygon([coordinates]))

        let camera = mapboxMap.camera(
            for: geometry,
            padding: .zero,
            bearing: 0,
            pitch: 0)

        XCTAssertEqual(expectedCenter.latitude, camera.center!.latitude, accuracy: 0.25)
        XCTAssertEqual(expectedCenter.longitude, camera.center!.longitude, accuracy: 0.25)
        XCTAssertEqual(camera.bearing, 0)
        XCTAssertEqual(camera.padding, .zero)
        XCTAssertEqual(camera.pitch, 0)
    }

    func testProtocolConformance() {
        // Compilation check only
        _ = mapboxMap as MapFeatureQueryable
    }

    func testBeginAndEndAnimation() {
        XCTAssertFalse(mapboxMap.__testingMap.isUserAnimationInProgress())

        mapboxMap.beginAnimation()

        XCTAssertTrue(mapboxMap.__testingMap.isUserAnimationInProgress())

        mapboxMap.beginAnimation()

        XCTAssertTrue(mapboxMap.__testingMap.isUserAnimationInProgress())

        mapboxMap.endAnimation()

        XCTAssertTrue(mapboxMap.__testingMap.isUserAnimationInProgress())

        mapboxMap.beginAnimation()

        XCTAssertTrue(mapboxMap.__testingMap.isUserAnimationInProgress())

        mapboxMap.endAnimation()

        XCTAssertTrue(mapboxMap.__testingMap.isUserAnimationInProgress())

        mapboxMap.endAnimation()

        XCTAssertFalse(mapboxMap.__testingMap.isUserAnimationInProgress())
    }

    func testBeginAndEndGesture() {
        XCTAssertFalse(mapboxMap.__testingMap.isGestureInProgress())

        mapboxMap.beginGesture()

        XCTAssertTrue(mapboxMap.__testingMap.isGestureInProgress())

        mapboxMap.beginGesture()

        XCTAssertTrue(mapboxMap.__testingMap.isGestureInProgress())

        mapboxMap.endGesture()

        XCTAssertTrue(mapboxMap.__testingMap.isGestureInProgress())

        mapboxMap.beginGesture()

        XCTAssertTrue(mapboxMap.__testingMap.isGestureInProgress())

        mapboxMap.endGesture()

        XCTAssertTrue(mapboxMap.__testingMap.isGestureInProgress())

        mapboxMap.endGesture()

        XCTAssertFalse(mapboxMap.__testingMap.isGestureInProgress())
    }

    func testLoadStyleHandlerIsInvokedExactlyOnce() throws {
        let completionIsCalledOnce = expectation(description: "loadStyle completion should be called once")
        completionIsCalledOnce.assertForOverFulfill = true

        mapboxMap.loadStyleURI(.dark) { _ in
            completionIsCalledOnce.fulfill()
        }
        let interval = EventTimeInterval(begin: .init(), end: .init())
        events.onStyleLoaded.send(StyleLoaded(timeInterval: interval))
        events.onStyleLoaded.send(StyleLoaded(timeInterval: interval))

        waitForExpectations(timeout: 0.3)
    }

    func testEvents() {
        func checkEvent<T>(
            _ subjectKeyPath: KeyPath<MapEvents, SignalSubject<T>>,
            _ signalKeyPath: KeyPath<MapboxMap, Signal<T>>,
            value: T) {
                var count = 0
                let cancelable = mapboxMap[keyPath: signalKeyPath].observe { _ in
                    count += 1
                }

                mapboxMap.performWithoutNotifying {
                    events[keyPath: subjectKeyPath].send(value)
                }
                XCTAssertEqual(count, 0, "event not sent due to mute")

                events[keyPath: subjectKeyPath].send(value)
                XCTAssertEqual(count, 1, "event sent")

                cancelable.cancel()

                events[keyPath: subjectKeyPath].send(value)
                XCTAssertEqual(count, 1, "event not sent due to cancel")
        }

        let timeInterval = EventTimeInterval(begin: Date(), end: Date())
        let mapLoaded = MapLoaded(timeInterval: timeInterval)
        let mapLoadingError = MapLoadingError(
            type: .source,
            message: "message",
            sourceId: nil,
            tileId: nil,
            timestamp: Date())
        let cameraChanged = CameraChanged(
            cameraState: CameraState(center: .random(), padding: .random(), zoom: 0, bearing: 0, pitch: 0),
            timestamp: Date())

        checkEvent(\.onMapIdle, \.onMapIdle, value: MapIdle(timestamp: Date()))
        checkEvent(\.onMapLoaded, \.onMapLoaded, value: mapLoaded)
        checkEvent(\.onStyleLoaded, \.onStyleLoaded, value: StyleLoaded(timeInterval: timeInterval))
        checkEvent(\.onStyleDataLoaded, \.onStyleDataLoaded, value: StyleDataLoaded(type: .style, timeInterval: timeInterval))
        checkEvent(\.onMapLoadingError, \.onMapLoadingError, value: mapLoadingError)
        checkEvent(\.onCameraChanged, \.onCameraChanged, value: cameraChanged)
        checkEvent(\.onSourceAdded, \.onSourceAdded, value: SourceAdded(sourceId: "foo", timestamp: Date()))
        checkEvent(\.onSourceRemoved, \.onSourceRemoved, value: SourceRemoved(sourceId: "foo", timestamp: Date()))
        checkEvent(\.onStyleImageMissing, \.onStyleImageMissing, value: StyleImageMissing(imageId: "bar", timestamp: Date()))
        checkEvent(\.onStyleImageRemoveUnused, \.onStyleImageRemoveUnused, value: StyleImageRemoveUnused(imageId: "bar", timestamp: Date()))
        checkEvent(\.onRenderFrameStarted, \.onRenderFrameStarted, value: RenderFrameStarted(timestamp: Date()))
        checkEvent(\.onRenderFrameFinished, \.onRenderFrameFinished, value: RenderFrameFinished(renderMode: .full, needsRepaint: true, placementChanged: true, timeInterval: timeInterval))

        let resourceRequest =  ResourceRequest(
            source: .network,
            request: RequestInfo(
                url: "https://mapbox.com",
                resource: .glyphs,
                priority: .regular,
                loadingMethod: [NSNumber(value: RequestLoadingMethodType.network.rawValue)]),
            response: nil, cancelled: false, timeInterval: timeInterval)
        checkEvent(\.onResourceRequest, \.onResourceRequest, value: resourceRequest)
    }

    func testGenericEvents() {
        var cancelables = Set<AnyCancelable>()
        var received = [GenericEvent]()
        mapboxMap["foo"].observe { received.append($0) }.store(in: &cancelables)

        let timeInterval = EventTimeInterval(begin: Date(), end: Date())
        let e1 = GenericEvent(name: "foo", data: 0, timeInterval: timeInterval)
        let e2 = GenericEvent(name: "foo", data: 0, timeInterval: timeInterval)

        fooGenericSubject?.send(e1)
        XCTAssertIdentical(received.last, e1)

        mapboxMap.performWithoutNotifying {
            fooGenericSubject?.send(e2)
        }

        XCTAssertIdentical(received.last, e1, "event not sent due to mute")

        fooGenericSubject?.send(e2)
        XCTAssertIdentical(received.last, e2)
    }

    @available(*, deprecated)
    func testOnTypedNext() throws {
        let mapLoadedStub = Stub<MapLoaded, Void>()
        let token = mapboxMap.onNext(event: .mapLoaded, handler: mapLoadedStub.call(with:))
        defer { token.cancel() }

        let mapLoaded1 = MapLoaded(timeInterval: EventTimeInterval(begin: Date(), end: Date()))
        let mapLoaded2 = MapLoaded(timeInterval: EventTimeInterval(begin: Date(), end: Date()))
        events.onMapLoaded.send(mapLoaded1)
        events.onMapLoaded.send(mapLoaded2)

        XCTAssertEqual(mapLoadedStub.invocations.count, 1)
        XCTAssertIdentical(mapLoadedStub.invocations[0].parameters, mapLoaded1)

        // ignored cancellable
        let sourceAddedStub = Stub<SourceAdded, Void>()
        mapboxMap.onNext(event: .sourceAdded, handler: sourceAddedStub.call(with:))

        let sourceAdded1 = SourceAdded(sourceId: "source-id-1", timestamp: Date())
        let sourceAdded2 = SourceAdded(sourceId: "source-id-2", timestamp: Date())
        events.onSourceAdded.send(sourceAdded1)
        events.onSourceAdded.send(sourceAdded2)
        events.onSourceAdded.send(sourceAdded2)

        XCTAssertEqual(mapLoadedStub.invocations.count, 1)
        XCTAssertIdentical(sourceAddedStub.invocations[0].parameters, sourceAdded1)
    }

    @available(*, deprecated)
    func testOnTypedEvery() throws {
        let mapLoadedStub = Stub<MapLoaded, Void>()
        let token = mapboxMap.onEvery(event: .mapLoaded, handler: mapLoadedStub.call(with:))
        defer { token.cancel() }

        let mapLoaded1 = MapLoaded(timeInterval: EventTimeInterval(begin: Date(), end: Date()))
        let mapLoaded2 = MapLoaded(timeInterval: EventTimeInterval(begin: Date(), end: Date()))
        events.onMapLoaded.send(mapLoaded1)
        events.onMapLoaded.send(mapLoaded2)

        XCTAssertIdentical(mapLoadedStub.invocations[0].parameters, mapLoaded1)
        XCTAssertIdentical(mapLoadedStub.invocations[1].parameters, mapLoaded2)

        // ignored cancellable
        let sourceAddedStub = Stub<SourceAdded, Void>()
        mapboxMap.onEvery(event: .sourceAdded, handler: sourceAddedStub.call(with:))

        let sourceAdded1 = SourceAdded(sourceId: "source-id-1", timestamp: Date())
        let sourceAdded2 = SourceAdded(sourceId: "source-id-2", timestamp: Date())
        events.onSourceAdded.send(sourceAdded1)
        events.onSourceAdded.send(sourceAdded2)

        XCTAssertIdentical(sourceAddedStub.invocations[0].parameters, sourceAdded1)
        XCTAssertIdentical(sourceAddedStub.invocations[1].parameters, sourceAdded2)
    }

    func testPerformWithoutNotifying() throws {
        let stub = Stub<MapIdle, Void>()
        let token = mapboxMap.onMapIdle.observe(stub.call(with:))
        defer { token.cancel() }

        let mapIdle1 = MapIdle(timestamp: Date())
        let mapIdle2 = MapIdle(timestamp: Date())
        events.onMapIdle.send(mapIdle1)

        // no block
        XCTAssertEqual(stub.invocations.count, 1)
        XCTAssertIdentical(stub.invocations[0].parameters, mapIdle1)

        // block
        mapboxMap.performWithoutNotifying {
            events.onMapIdle.send(mapIdle2)
        }
        XCTAssertEqual(stub.invocations.count, 1)

        // no block again
        events.onMapIdle.send(mapIdle2)
        XCTAssertEqual(stub.invocations.count, 2)
        XCTAssertIdentical(stub.invocations[1].parameters, mapIdle2)
    }
}
