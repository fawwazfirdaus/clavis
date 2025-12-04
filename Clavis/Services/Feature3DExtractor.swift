//
//  Feature3DExtractor.swift
//  Clavis
//
//  Created on 12/26/25.
//

import Foundation
import ARKit
import simd

/// Extracts 3D features from ARKit point clouds for object recognition.
/// Uses geometric features and spatial descriptors to create robust 3D feature vectors.
class Feature3DExtractor {
    static let shared = Feature3DExtractor()
    
    private init() {}
    
    /// Extracts 3D features from a point cloud.
    /// - Parameters:
    ///   - pointCloud: Array of 3D points (simd_float3) in world space
    ///   - roi: Optional region of interest (normalized coordinates)
    /// - Returns: Feature vector as array of floats, or nil if extraction fails
    func extractFeatures(pointCloud: [simd_float3], roi: CGRect? = nil) -> [Float]? {
        guard !pointCloud.isEmpty else {
            print("❌ [Feature3DExtractor] Empty point cloud")
            return nil
        }
        
        print("🔍 [Feature3DExtractor] Extracting features from \(pointCloud.count) points...")
        
        // Filter points by ROI if specified (points should already be filtered, but double-check)
        let filteredPoints = pointCloud
        
        // Extract multiple types of 3D features
        var features: [Float] = []
        
        // 1. Geometric features (centroid, bounding box, principal axes)
        if let geometricFeatures = extractGeometricFeatures(points: filteredPoints) {
            features.append(contentsOf: geometricFeatures)
        }
        
        // 2. Spatial distribution features (histogram of point distribution)
        if let distributionFeatures = extractDistributionFeatures(points: filteredPoints) {
            features.append(contentsOf: distributionFeatures)
        }
        
        // 3. Surface features (normal vectors, curvature estimates)
        if let surfaceFeatures = extractSurfaceFeatures(points: filteredPoints) {
            features.append(contentsOf: surfaceFeatures)
        }
        
        // 4. Statistical features (mean, variance, moments)
        if let statisticalFeatures = extractStatisticalFeatures(points: filteredPoints) {
            features.append(contentsOf: statisticalFeatures)
        }
        
        guard !features.isEmpty else {
            print("❌ [Feature3DExtractor] Failed to extract any features")
            return nil
        }
        
        // Normalize features to [0, 1] range for better matching
        let normalizedFeatures = normalizeFeatures(features)
        
        print("✅ [Feature3DExtractor] Extracted \(normalizedFeatures.count) features")
        return normalizedFeatures
    }
    
    // MARK: - Geometric Features
    
    private func extractGeometricFeatures(points: [simd_float3]) -> [Float]? {
        guard !points.isEmpty else { return nil }
        
        var features: [Float] = []
        
        // Centroid
        let centroid = computeCentroid(points: points)
        features.append(centroid.x)
        features.append(centroid.y)
        features.append(centroid.z)
        
        // Bounding box dimensions
        let (minBounds, maxBounds) = computeBoundingBox(points: points)
        let dimensions = maxBounds - minBounds
        features.append(dimensions.x)
        features.append(dimensions.y)
        features.append(dimensions.z)
        
        // Bounding box center
        let boxCenter = (minBounds + maxBounds) / 2.0
        features.append(boxCenter.x)
        features.append(boxCenter.y)
        features.append(boxCenter.z)
        
        // Principal axes (simplified - use first 3 principal components)
        if let principalAxes = computePrincipalAxes(points: points) {
            features.append(contentsOf: principalAxes)
        }
        
        return features
    }
    
    // MARK: - Distribution Features
    
    private func extractDistributionFeatures(points: [simd_float3]) -> [Float]? {
        guard !points.isEmpty else { return nil }
        
        var features: [Float] = []
        
        // Compute centroid for distribution
        let centroid = computeCentroid(points: points)
        
        // Histogram of distances from centroid (8 bins)
        let distances = points.map { simd_distance($0, centroid) }
        let maxDist = distances.max() ?? 1.0
        var histogram = Array(repeating: 0, count: 8)
        
        for dist in distances {
            let bin = min(7, Int((dist / maxDist) * 8))
            histogram[bin] += 1
        }
        
        // Normalize histogram
        let total = Float(points.count)
        for count in histogram {
            features.append(Float(count) / total)
        }
        
        // Angular distribution (spherical coordinates)
        var angularHistogram = Array(repeating: 0, count: 16)  // 16 angular bins
        for point in points {
            let relativePoint = point - centroid
            let theta = atan2(relativePoint.y, relativePoint.x)  // Azimuth
            let bin = Int(((theta + .pi) / (2 * .pi)) * 16) % 16
            angularHistogram[bin] += 1
        }
        
        // Normalize angular histogram
        for count in angularHistogram {
            features.append(Float(count) / total)
        }
        
        return features
    }
    
    // MARK: - Surface Features
    
    private func extractSurfaceFeatures(points: [simd_float3]) -> [Float]? {
        guard points.count >= 3 else { return nil }
        
        var features: [Float] = []
        
        // Estimate surface normals (simplified - use local neighborhoods)
        var normalVectors: [simd_float3] = []
        let kNeighbors = min(10, points.count / 4)  // Use k nearest neighbors
        
        for point in points.prefix(100) {  // Sample first 100 points for performance
            let neighbors = findKNearestNeighbors(point: point, points: points, k: kNeighbors)
            if let normal = estimateNormal(point: point, neighbors: neighbors) {
                normalVectors.append(normal)
            }
        }
        
        if !normalVectors.isEmpty {
            // Average normal vector
            let avgNormal = normalVectors.reduce(simd_float3(0, 0, 0), +) / Float(normalVectors.count)
            let normalizedAvg = simd_normalize(avgNormal)
            features.append(normalizedAvg.x)
            features.append(normalizedAvg.y)
            features.append(normalizedAvg.z)
            
            // Normal variance (surface roughness)
            let normalVariance = computeVariance(vectors: normalVectors)
            features.append(normalVariance)
        } else {
            // Fallback: zero features
            features.append(contentsOf: [0, 0, 0, 0])
        }
        
        return features
    }
    
    // MARK: - Statistical Features
    
    private func extractStatisticalFeatures(points: [simd_float3]) -> [Float]? {
        guard !points.isEmpty else { return nil }
        
        var features: [Float] = []
        
        // Mean and variance for each axis
        let xValues = points.map { $0.x }
        let yValues = points.map { $0.y }
        let zValues = points.map { $0.z }
        
        features.append(mean(xValues))
        features.append(variance(xValues))
        features.append(mean(yValues))
        features.append(variance(yValues))
        features.append(mean(zValues))
        features.append(variance(zValues))
        
        // Point density (points per unit volume)
        let (minBounds, maxBounds) = computeBoundingBox(points: points)
        let volume = (maxBounds.x - minBounds.x) * (maxBounds.y - minBounds.y) * (maxBounds.z - minBounds.z)
        let density = volume > 0 ? Float(points.count) / volume : 0
        features.append(density)
        
        return features
    }
    
    // MARK: - Helper Functions
    
    private func computeCentroid(points: [simd_float3]) -> simd_float3 {
        let sum = points.reduce(simd_float3(0, 0, 0), +)
        return sum / Float(points.count)
    }
    
    private func computeBoundingBox(points: [simd_float3]) -> (min: simd_float3, max: simd_float3) {
        guard let first = points.first else {
            return (simd_float3(0, 0, 0), simd_float3(0, 0, 0))
        }
        
        var minBounds = first
        var maxBounds = first
        
        for point in points {
            minBounds = simd_min(minBounds, point)
            maxBounds = simd_max(maxBounds, point)
        }
        
        return (minBounds, maxBounds)
    }
    
    private func computePrincipalAxes(points: [simd_float3]) -> [Float]? {
        guard points.count >= 3 else { return nil }
        
        // Simplified PCA: compute covariance matrix and extract first 3 eigenvectors
        let centroid = computeCentroid(points: points)
        var covariance = simd_float3x3(0)
        
        for point in points {
            let diff = point - centroid
            covariance += simd_float3x3(
                simd_float3(diff.x * diff.x, diff.x * diff.y, diff.x * diff.z),
                simd_float3(diff.y * diff.x, diff.y * diff.y, diff.y * diff.z),
                simd_float3(diff.z * diff.x, diff.z * diff.y, diff.z * diff.z)
            )
        }
        
        // Divide each element by count
        let count = Float(points.count)
        covariance = simd_float3x3(
            covariance.columns.0 / count,
            covariance.columns.1 / count,
            covariance.columns.2 / count
        )
        
        // Extract diagonal (simplified - full PCA would require eigendecomposition)
        // For now, return diagonal elements as principal component approximation
        return [
            covariance.columns.0.x,
            covariance.columns.1.y,
            covariance.columns.2.z
        ]
    }
    
    private func findKNearestNeighbors(point: simd_float3, points: [simd_float3], k: Int) -> [simd_float3] {
        let distances = points.map { (point: $0, distance: simd_distance(point, $0)) }
        let sorted = distances.sorted { $0.distance < $1.distance }
        return Array(sorted.prefix(k).map { $0.point })
    }
    
    private func estimateNormal(point: simd_float3, neighbors: [simd_float3]) -> simd_float3? {
        guard neighbors.count >= 2 else { return nil }
        
        // Simple normal estimation: use cross product of two neighbor vectors
        let v1 = neighbors[0] - point
        let v2 = neighbors[1] - point
        let normal = simd_cross(v1, v2)
        let length = simd_length(normal)
        
        guard length > 0.001 else { return nil }
        return simd_normalize(normal)
    }
    
    private func computeVariance(vectors: [simd_float3]) -> Float {
        guard !vectors.isEmpty else { return 0 }
        
        let mean = vectors.reduce(simd_float3(0, 0, 0), +) / Float(vectors.count)
        let squaredDiffs = vectors.map { simd_length_squared($0 - mean) }
        return squaredDiffs.reduce(0, +) / Float(vectors.count)
    }
    
    private func mean(_ values: [Float]) -> Float {
        return values.reduce(0, +) / Float(values.count)
    }
    
    private func variance(_ values: [Float]) -> Float {
        let m = mean(values)
        let squaredDiffs = values.map { ($0 - m) * ($0 - m) }
        return squaredDiffs.reduce(0, +) / Float(values.count)
    }
    
    private func normalizeFeatures(_ features: [Float]) -> [Float] {
        // Min-max normalization to [0, 1] range
        guard let minVal = features.min(), let maxVal = features.max() else {
            return features
        }
        
        let range = maxVal - minVal
        guard range > 0.001 else {
            return features.map { _ in 0.5 }  // All same value, return neutral
        }
        
        return features.map { ($0 - minVal) / range }
    }
}

