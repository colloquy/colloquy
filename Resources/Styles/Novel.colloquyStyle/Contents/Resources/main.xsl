<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:output omit-xml-declaration="yes" indent="no" />
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

	<xsl:template match="event">
		<div class="event">
			<xsl:copy-of select="message/child::node()" />
			<xsl:if test="reason!=''">
				<span class="reason">
					<xsl:text> (</xsl:text>
					<xsl:apply-templates select="reason/child::node()" mode="copy"/>
					<xsl:text>)</xsl:text>
				</span>
			</xsl:if>
		</div>
	</xsl:template>

	<xsl:template match="message">
		<span class="submessage">
		<xsl:if test="@action = 'yes'">
			<xsl:value-of select="../sender" />
			<xsl:text> </xsl:text>
		</xsl:if>
		<xsl:value-of select="normalize-space(.)" />
		</span>
		<xsl:if test="$subsequent = 'yes'">
			<span id="consecutiveInsert" />
		</xsl:if>
	</xsl:template>

	<xsl:template match="envelope">
		<xsl:variable name="envelopeClass">
			<xsl:choose>
				<xsl:when test="message/@highlight = 'yes'">
					<xsl:text>envelopeHighlight</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>envelope</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<xsl:variable name="senderClass">
			<xsl:choose>
				<xsl:when test="sender/@self = 'yes'">
					<xsl:text>senderSelf</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>sender</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<div id="{@id}" class="{$envelopeClass}">
			<xsl:choose>
				<xsl:when test="message[1]/@action = 'yes'">
					<span class="{$senderClass}"><xsl:value-of select="sender" /></span>
					<xsl:text> </xsl:text>
					<xsl:value-of select="normalize-space(message[1])" />
					<xsl:text> </xsl:text>
					<q lang="en">
						<xsl:apply-templates select="message[position() &gt; 1]" />
						<xsl:if test="position() = last()">
							<span id="consecutiveInsert" />
						</xsl:if>
					</q>
				</xsl:when>
				<xsl:when test="contains(message[1], ',')">
					<q lang="en">
						<span class="message"><xsl:value-of select="normalize-space(substring-before( message[1], ',' ))" /></span>
						<xsl:text>,</xsl:text>
					</q>
					<xsl:text> </xsl:text>
					<span class="{$senderClass}"><xsl:value-of select="sender" /></span>
					<xsl:choose>
						<xsl:when test="substring( message[1], string-length( message[1] ), 1 ) = '?'">
							<xsl:text> asks </xsl:text>
						</xsl:when>
						<xsl:when test="substring( message[1], string-length( message[1] ), 1 ) = '!'">
							<xsl:text> exclaims </xsl:text>
						</xsl:when>
						<xsl:otherwise>
							<xsl:text> says </xsl:text>
						</xsl:otherwise>
					</xsl:choose>
					<q lang="en">
						<span class="message"><xsl:value-of select="normalize-space(substring-after( message[1], ',' ))" /></span>
						<xsl:apply-templates select="message[position() &gt; 1]" />
						<xsl:if test="position() = last()">
							<span id="consecutiveInsert" />
						</xsl:if>
					</q>
				</xsl:when>
				<xsl:otherwise>
					<q lang="en">
						<span class="message"><xsl:value-of select="normalize-space(message[1])" /></span>
						<xsl:text>,</xsl:text>
					</q>
					<xsl:choose>
						<xsl:when test="substring( message[1], string-length( message[1] ), 1 ) = '?'">
							<xsl:text> asked </xsl:text>
						</xsl:when>
						<xsl:when test="substring( message[1], string-length( message[1] ), 1 ) = '!'">
							<xsl:text> exclaimed </xsl:text>
						</xsl:when>
						<xsl:otherwise>
							<xsl:text> said </xsl:text>
						</xsl:otherwise>
					</xsl:choose>
					<span class="{$senderClass}"><xsl:value-of select="sender" /></span>
					<xsl:text>. </xsl:text>
					<q lang="en">
						<xsl:apply-templates select="message[position() &gt; 1]" />
						<xsl:if test="position() = last()">
							<span id="consecutiveInsert" />
						</xsl:if>
					</q>
				</xsl:otherwise>
			</xsl:choose>
		</div>
	</xsl:template>
</xsl:transform>
