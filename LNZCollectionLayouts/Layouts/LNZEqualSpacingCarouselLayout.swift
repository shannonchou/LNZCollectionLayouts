//
//  LNZEqualSpacingCarouselLayout.swift
//  LNZCollectionLayouts
//
//  Created by shannonchou on 2020/5/23.
//

import UIKit

/**
 The different between LNZEqualSpacingCarouselLayout and LNZCarouselCollectionViewLayout is that,
 LNZEqualSpacingCarouselLayout can make inner spaces between cells be equal. Moreover, you can define a different space
 beside the center cell.

 This collectionView layout handles just one section without header and footer, and cells always be vertical centered.
 */
@IBDesignable @objcMembers
open class LNZEqualSpacingCarouselLayout: LNZSnapToCenterCollectionViewLayout {

    // MARK: - Inspectable properties

    /// This property determines how fast each item not in focus will reach the minimum size. The size
    /// of each item depends from the item.center position related to the collection's center, and it
    /// will be *zoomInItemSize* if the element is in the center, and *itemSize* if
    /// |item.center - collection.center| >= *scalingOffset*
    @IBInspectable public var scalingOffset: CGFloat = 80
    @IBInspectable public var zoomInItemSize: CGSize = CGSize(width: 75, height: 75)
    @IBInspectable public var zoomInInterItemSpacing: CGFloat = 8
    @IBOutlet public weak var carouselDelegate: CarouselDelegate?
    public var decelerationRate: UIScrollView.DecelerationRate = .fast

    // MARK: - Utility properties

    typealias LayoutAttributesZoomInfo = (attributes: UICollectionViewLayoutAttributes, spacing: CGFloat)
    var cachedAttributes: [IndexPath: LayoutAttributesZoomInfo] = [:]
    var itemWidthWithSpacing: CGFloat = 1

    // MARK: - Layout implementation

    private func centerCellIndex() -> IndexPath {
        guard let collection = collectionView else { return IndexPath(row: 0, section: 0) }
        let xOffset = collection.contentOffset.x
        let currentCellIndex = (xOffset + itemWidthWithSpacing / 2.0) / itemWidthWithSpacing
        let zoomedCellIndex = min(max(0, Int(currentCellIndex)), collection.numberOfItems(inSection: 0) - 1)
        return IndexPath(row: zoomedCellIndex, section: 0)
    }

    private func zoomedInterSpacing(of progress: CGFloat) -> CGFloat {
        return interItemSpacing + (zoomInInterItemSpacing - interItemSpacing) * progress
    }

    private func zoomedItemSize(of progress: CGFloat) -> CGSize {
        return itemSize + (zoomInItemSize - itemSize) * progress
    }

    private func relativeDisplacement(at index: Int, offset: CGFloat) -> CGFloat {
        let relativeDisplacement = (offset - (itemWidthWithSpacing * CGFloat(index) - itemWidthWithSpacing / 2)) / itemWidthWithSpacing
        return relativeDisplacement
    }

    // MARK: Preparation

    open override func prepare() {
        super.prepare()
        itemWidthWithSpacing = itemSize.width + interItemSpacing
        cachedAttributes.removeAll()
        collectionView?.decelerationRate = decelerationRate
    }

    // MARK: Layouting and attributes generators

    /// When calculate a LayoutAttributes, recursively find a calculated neighbor LayoutAttributes which closer the
    /// center one.
    /// - Parameter attributes: attributes to be configurated
    private func configureAttributes(for attributes: UICollectionViewLayoutAttributes) {
        guard let collection = collectionView, cachedAttributes[attributes.indexPath] == nil else { return }
        let centerIndex = centerCellIndex()
        let contentOffset = collection.contentOffset
        let collectionViewSize = collection.bounds.size
        let visibleRect = CGRect(x: contentOffset.x, y: contentOffset.y, width: collectionViewSize.width, height: collectionViewSize.height)
        let visibleCenterX = visibleRect.midX

        let distanceFromCenter = visibleCenterX - attributes.center.x
        let absDistanceFromCenter = min(abs(distanceFromCenter), scalingOffset)
        // progress of the state from zoom out to zoom in
        let progress = 1 - absDistanceFromCenter / scalingOffset
        let itemSizeZoomed = zoomedItemSize(of: progress)
        let interSpacingZoomed = zoomedInterSpacing(of: progress)
        let abstractFrame = frameForItem(at: attributes.indexPath)
        attributes.center = CGPoint(x: abstractFrame.midX, y: abstractFrame.midY)
        attributes.size = abstractFrame.size
        let targetFrame: CGRect
        if centerIndex == attributes.indexPath {
            let relative = relativeDisplacement(at: centerIndex.row, offset: contentOffset.x)
            targetFrame = CGRect(x: collection.frame.size.width / 2 + contentOffset.x - itemSizeZoomed.width * relative -
                (interSpacingZoomed * relative - interSpacingZoomed / 2),
                y: (collectionViewSize.height - itemSizeZoomed.height) / 2,
                width: itemSizeZoomed.width,
                height: itemSizeZoomed.height)
        } else if centerIndex > attributes.indexPath { // left cells
            let neighborIndex = attributes.indexPath.next()
            guard let (neighbor, neighborSpacing) = cachedAttributes[neighborIndex] ?? {
                _ = layoutAttributesForItem(at: neighborIndex)
                return cachedAttributes[neighborIndex]
            }() else { return }
            let neighborTargetFrame = neighbor.frame
            targetFrame = CGRect(x: neighborTargetFrame.minX - neighborSpacing / 2 - interSpacingZoomed / 2 - itemSizeZoomed.width,
                                 y: (collectionViewSize.height - itemSizeZoomed.height) / 2,
                                 width: itemSizeZoomed.width,
                                 height: itemSizeZoomed.height)
        } else { // right cells
            let neighborIndex = attributes.indexPath.previous()
            guard let (neighbor, neighborSpacing) = cachedAttributes[neighborIndex] ?? {
                _ = layoutAttributesForItem(at: neighborIndex)
                return cachedAttributes[neighborIndex]
            }() else { return }
            let neighborTargetFrame = neighbor.frame
            targetFrame = CGRect(x: neighborTargetFrame.maxX + neighborSpacing / 2 + interSpacingZoomed / 2,
                                 y: (collectionViewSize.height - itemSizeZoomed.height) / 2,
                                 width: itemSizeZoomed.width,
                                 height: itemSizeZoomed.height)
        }
        let scaleTrans = CGAffineTransform(scaleX: targetFrame.width / abstractFrame.width, y: targetFrame.height / abstractFrame.height)
        let moveTans = CGAffineTransform(translationX: targetFrame.midX - abstractFrame.midX, y: targetFrame.midY - abstractFrame.midY)
        attributes.transform = scaleTrans.concatenating(moveTans)
        cachedAttributes[attributes.indexPath] = (attributes, interSpacingZoomed)
        // All the elements that are smaller are not in focus, therefore they should have a smaller zIndex so that if
        //they will overlap accordingly to the perspective in case of a negative value for the *minimumLineSpacing*
        // property.
        attributes.zIndex = Int(progress * 100000)
        carouselDelegate?.carouselContainer?(self, didLayoutAttributes: attributes)
    }

    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }
        // Here we rely on super layout implementation, because we know that the parent layout is able to handle the
        // situation of no infinite scrolling, in case of *canInfiniteScroll* to be false. Since we did override the
        // *canInfiniteScroll* to consider also the *isInfiniteScrollEnabled* property, we are safe to have the required
        // behavior from this layout.

        // All we have to do at this point is to apply the scale factor to the attributes we already have.
        for attribute in attributes where attribute.representedElementCategory == .cell {
            configureAttributes(for: attribute)
        }
        return cachedAttributes.values.map { $0.attributes }
    }

    open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attribute = super.layoutAttributesForItem(at: indexPath) else { return nil }
        configureAttributes(for: attribute)
        return attribute
    }

    public func scrollToItem(at indexPath: IndexPath) {
        let offset = itemWidthWithSpacing * CGFloat(indexPath.row)
        collectionView?.setContentOffset(CGPoint(x: offset, y: 0), animated: true)
    }
}

fileprivate extension CGSize {

    static func * (lhs: CGSize, scalar: CGFloat) -> CGSize {
        return CGSize(width: lhs.width * scalar, height: lhs.height * scalar)
    }

    static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }

    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}

fileprivate extension IndexPath {

    func previous() -> IndexPath {
        return IndexPath(row: row - 1, section: section)
    }

    func next() -> IndexPath {
        return IndexPath(row: row + 1, section: section)
    }
}
