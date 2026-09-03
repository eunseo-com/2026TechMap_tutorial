import simd

enum TreeHidePlanner {
    static func destination(
        treeCenter: SIMD3<Float>,
        treeRadius: Float,
        cameraPosition: SIMD3<Float>,
        pigRadius: Float,
        floorY: Float
    ) -> SIMD3<Float> {
        let towardCamera = SIMD3(
            cameraPosition.x - treeCenter.x,
            0,
            cameraPosition.z - treeCenter.z
        )
        let direction = simd_length_squared(towardCamera) > 0.0001
            ? simd_normalize(towardCamera)
            : SIMD3<Float>(0, 0, 1)
        let distance = treeRadius + pigRadius + 0.08

        return SIMD3(
            treeCenter.x - direction.x * distance,
            floorY,
            treeCenter.z - direction.z * distance
        )
    }
}
