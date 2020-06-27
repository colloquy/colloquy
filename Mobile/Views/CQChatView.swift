import UIKit

@objc
@objcMembers
internal final class CQChatView: UIView {
	internal let chatInputBar = CQChatInputBar(frame: .zero)
	internal let chatTranscriptView: CQChatTranscriptView & UIView = CQWKChatTranscriptView(frame: .zero)

	override init(frame: CGRect) {
		super.init(frame: frame)

		addSubview(chatInputBar)
		addSubview(chatTranscriptView)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		let slices = bounds.divided(atDistance: 44.0, from: .maxYEdge)
		chatInputBar.frame = slices.slice
		chatTranscriptView.frame = slices.remainder
	}
}
