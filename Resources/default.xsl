<?xml version='1.0' encoding='iso-8859-1'?>
<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>
	<xsl:output omit-xml-declaration="yes" indent="yes" />
	<xsl:param name="subsequent" />

	<xsl:template match="/">
		<xsl:choose>
			<xsl:when test="$subsequent != 'yes'">
				<xsl:apply-templates />
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates select="/envelope/message[last()]" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="envelope | message">
		<xsl:variable name="envelopeClasses">
			<xsl:choose>
				<xsl:when test="(message[1]/@highlight = 'yes' and message[1]/@action = 'yes') or (@highlight = 'yes' and /@action = 'yes')">
					<xsl:text>envelope highlight action</xsl:text>
				</xsl:when>
				<xsl:when test="message[1]/@action = 'yes' or @action = 'yes'">
					<xsl:text>envelope action</xsl:text>
				</xsl:when>
				<xsl:when test="message[1]/@highlight = 'yes' or @highlight = 'yes'">
					<xsl:text>envelope highlight</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>envelope</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<xsl:variable name="senderClasses">
			<xsl:choose>
				<xsl:when test="sender/@self = 'yes' or ../sender/@self = 'yes'">
					<xsl:text>member self</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>member</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<xsl:variable name="properIdentifier">
			<xsl:choose>
				<xsl:when test="@id">
					<xsl:value-of select="@id" />
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="../@id" />
					<xsl:text>.</xsl:text>
					<xsl:value-of select="position()" />
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<div id="{$properIdentifier}" class="{$envelopeClasses}">
			<span class="{$senderClasses}"><xsl:value-of select="sender | ../sender" /></span>
			<span class="timestamp">
				<xsl:call-template name="short-time">
					<xsl:with-param name="date" select="message[1]/@received | @received" />
				</xsl:call-template>
			</span>
			<span class="message">
				<xsl:choose>
					<xsl:when test="message[1]">
						<xsl:copy-of select="message[1]/child::node()" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:copy-of select="child::node()" />
					</xsl:otherwise>
				</xsl:choose>
			</span>
		</div>

		<xsl:apply-templates select="message[position() &gt; 1]" />
	</xsl:template>

	<xsl:template match="event">
		<div class="event">
			<xsl:copy-of select="message/child::node()" />
		</div>
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