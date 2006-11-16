<?xml version='1.0' encoding='iso-8859-1'?>
<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>
	<xsl:output omit-xml-declaration="yes" indent="no" />
	<xsl:param name="bulkTransform" />
	<xsl:param name="consecutiveMessage" />

	<xsl:template match="/">
		<xsl:choose>
			<xsl:when test="$consecutiveMessage = 'yes'">
				<xsl:apply-templates select="/envelope/message[last()]" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="envelope | message">
		<xsl:variable name="envelopeClasses">
			<xsl:text>envelope</xsl:text>
			<xsl:if test="message[1]/@highlight = 'yes' or @highlight = 'yes'">
				<xsl:text> highlight</xsl:text>
			</xsl:if>
			<xsl:if test="message[1]/@action = 'yes' or @action = 'yes'">
				<xsl:text> action</xsl:text>
			</xsl:if>
			<xsl:if test="message[1]/@type = 'notice' or @type = 'notice'">
				<xsl:text> notice</xsl:text>
			</xsl:if>
			<xsl:if test="message[1]/@ignored = 'yes' or @ignored = 'yes' or ../@ignored = 'yes'">
				<xsl:text> ignore</xsl:text>
			</xsl:if>
		</xsl:variable>

		<xsl:variable name="senderClasses">
			<xsl:text>member</xsl:text>
			<xsl:if test="sender/@self = 'yes' or ../sender/@self = 'yes'">
				<xsl:text> self</xsl:text>
			</xsl:if>
		</xsl:variable>

		<xsl:variable name="senderNick" select="sender | ../sender" />

		<xsl:variable name="memberLink">
			<xsl:choose>
				<xsl:when test="sender/@identifier or ../sender/@identifier">
					<xsl:text>member:identifier:</xsl:text><xsl:value-of select="sender/@identifier | ../sender/@identifier" />
				</xsl:when>
				<xsl:when test="sender/@nickname or ../sender/@nickname">
					<xsl:text>member:</xsl:text><xsl:value-of select="sender/@nickname | ../sender/@nickname" />
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>member:</xsl:text><xsl:value-of select="sender | ../sender" />
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<!-- Not sure I caught all legal characters found in an IRC nick -->
		<xsl:variable name="senderHash" select="number(translate($senderNick,'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM-_^[]{}|','123456789012345678901234567890123456789012345678901234567890'))" />

		<!-- Lighter-weight alternate hash, but only tracks up to longest nick -->
		<!--<xsl:variable name="senderHash" select="string-length($senderNick)" />-->

		<xsl:variable name="senderColor">
			<xsl:choose>
				<xsl:when test="sender/@self = 'yes'">colorself</xsl:when>
				<xsl:when test="../sender/@self = 'yes'">colorself</xsl:when>
				<xsl:when test="string-length(sender/text()) &gt; 0">
					<xsl:value-of select="concat('color', $senderHash mod 15)" />
				</xsl:when>
				<xsl:when test="string-length(../sender/text()) &gt; 0">
					<xsl:value-of select="concat('colormore', $senderHash mod 15)" />
				</xsl:when>
			</xsl:choose>
		</xsl:variable>

		<div id="{message[1]/@id | @id}" class="{$envelopeClasses}">
			<span class="timestamp hidden">[</span>
			<span class="timestamp">
				<xsl:call-template name="short-time">
					<xsl:with-param name="date" select="message[1]/@received | @received" />
				</xsl:call-template>
			</span>
			<xsl:choose>
				<xsl:when test="message[1]/@action = 'yes' or @action = 'yes'">
					<span class="timestamp hidden">] <xsl:text disable-output-escaping="yes">&amp;raquo; </xsl:text></span>
				</xsl:when>
				<xsl:otherwise>
					<span class="timestamp hidden">] &lt;</span>
				</xsl:otherwise>
			</xsl:choose>
			<a href="{$memberLink}" class="{$senderClasses}"><span class="{$senderColor}"><xsl:value-of select="$senderNick" /></span></a>
			<xsl:choose>
				<xsl:when test="message[1]/@action = 'yes' or @action = 'yes'">
					<span class="hidden"><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text></span>
				</xsl:when>
				<xsl:otherwise>
					<span class="hidden">&gt; </span>
				</xsl:otherwise>
			</xsl:choose>
			<span class="message">
				<xsl:choose>
					<xsl:when test="message[1]">
						<xsl:apply-templates select="message[1]/child::node()" mode="copy" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:apply-templates select="child::node()" mode="copy" />
					</xsl:otherwise>
				</xsl:choose>
			</span>
		</div>

		<xsl:apply-templates select="message[position() &gt; 1]" />
	</xsl:template>

	<xsl:template match="event">
		<div class="event">
			<span class="timestamp hidden">[</span>
			<span class="timestamp">
				<xsl:call-template name="short-time">
					<xsl:with-param name="date" select="@occurred" />
				</xsl:call-template>
			</span>
			<span class="timestamp hidden">] </span>
			<span class="message">
				<xsl:apply-templates select="message/child::node()" mode="event" />
				<xsl:if test="string-length(reason)">
					<span class="reason">
						<xsl:text> (</xsl:text>
						<xsl:apply-templates select="reason/child::node()" mode="copy"/>
						<xsl:text>)</xsl:text>
					</span>
				</xsl:if>
			</span>
		</div>
	</xsl:template>

	<xsl:template match="span[contains(@class,'member')]" mode="event">
		<xsl:variable name="nickname" select="current()" />
		<xsl:choose>
			<xsl:when test="../../node()[node() = $nickname]/@hostmask">
				<xsl:variable name="hostmask" select="../../node()[node() = $nickname]/@hostmask" />
				<a href="member:{$nickname}" title="{$hostmask}" class="member"><xsl:value-of select="$nickname" /></a>
				<xsl:if test="../../@name = 'memberJoined' or ../../@name = 'memberParted'">
					<span class="hostmask">
						<xsl:text> (</xsl:text>
						<xsl:value-of select="$hostmask" />
						<xsl:text>) </xsl:text>
					</span>
				</xsl:if>
			</xsl:when>
			<xsl:otherwise>
				<a href="member:{$nickname}" class="member"><xsl:value-of select="$nickname" /></a>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="span[contains(@class,'member')]" mode="copy">
		<a href="member:{current()}" class="member"><xsl:value-of select="current()" /></a>
	</xsl:template>

	<xsl:template match="@*|*" mode="copy">
		<xsl:copy><xsl:apply-templates select="@*|node()" mode="copy" /></xsl:copy>
	</xsl:template>

	<xsl:template name="short-time">
		<xsl:param name="date" /> <!-- YYYY-MM-DD HH:MM:SS +/-HHMM -->
		<xsl:choose>
			<xsl:when test="number(substring($date, 12, 2)) &gt; 12">
				<xsl:value-of select="number(substring($date, 12, 2)) - 12" />
			</xsl:when>
			<xsl:when test="number(substring($date, 12, 2)) = 0">
				<xsl:text>12</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="number(substring($date, 12, 2))" />
			</xsl:otherwise>
		</xsl:choose>
		<xsl:text>:</xsl:text>
		<xsl:value-of select="substring($date, 15, 2)" />
		<xsl:choose>
			<xsl:when test="number(substring($date, 12, 2)) &gt;= 12">
				<xsl:text>pm</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:text>am</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:stylesheet>
