<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
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

	<xsl:template match="event">
		<div class="event">
			<xsl:apply-templates select="message/child::node()" mode="copy" />
			<xsl:text> (</xsl:text>
			<xsl:call-template name="short-time">
				<xsl:with-param name="date" select="@occurred" />
			</xsl:call-template>
			<xsl:text>)</xsl:text>
		</div>
	</xsl:template>

	<xsl:template match="message">
		<xsl:variable name="messageClass">
			<xsl:choose>
				<xsl:when test="../sender/@self = 'yes'">
					<xsl:text>submessage self</xsl:text>
				</xsl:when>
		        <xsl:when test="@highlight = 'yes'">
		          <xsl:text>submessage highlight</xsl:text>
		        </xsl:when>
				<xsl:otherwise>
					<xsl:text>submessage</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<div class="{$messageClass}">
			<span class="time">
				<xsl:call-template name="short-time">
					<xsl:with-param name="date" select="@received" />
				</xsl:call-template>
			</span>
      		<xsl:if test="@action = 'yes'">
				<xsl:text>&#8226; </xsl:text>
				<a href="member:{../sender}" class="member action">
				<xsl:value-of select="../sender" />
				</a>
				<xsl:text> </xsl:text>
			</xsl:if>
			<xsl:apply-templates select="child::node()" mode="copy" />
		</div>
		<xsl:if test="$subsequent = 'yes'">
			<div id="consecutiveInsert">&#8203;</div>
		</xsl:if>
	</xsl:template>

	<xsl:template match="envelope">
		<xsl:variable name="messageClass">
			<xsl:choose>
				<xsl:when test="sender/@self = 'yes'">
					<xsl:text>message self</xsl:text>
				</xsl:when>
		        <xsl:when test="message[1]/@highlight = 'yes'">
		          <xsl:text>message highlight</xsl:text>
		        </xsl:when>
				<xsl:otherwise>
					<xsl:text>message</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<div id="{@id}" class="{$messageClass}">
			<div class="header">
				<a href="member:{sender}" class="name"><xsl:value-of select="sender" /></a>
			</div>
			<span class="time">
				<xsl:call-template name="short-time">
					<xsl:with-param name="date" select="message[1]/@received" />
				</xsl:call-template>
			</span>
      		<xsl:if test="message[1]/@action = 'yes'">
				<xsl:text>&#8226; </xsl:text>
				<a href="member:{sender}" class="member action">
				<xsl:value-of select="sender" />
				</a>
				<xsl:text> </xsl:text>
			</xsl:if>
			<xsl:apply-templates select="message[1]/child::node()" mode="copy" />
		</div>
		<xsl:apply-templates select="message[position() &gt; 1]" />
		<xsl:if test="position() = last()">
			<div id="consecutiveInsert">&#8203;</div>
		</xsl:if>
		<div class="shadow">&#8203;</div>
	</xsl:template>

	<xsl:template match="span[@class='member']" mode="copy">
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
		<xsl:text>:</xsl:text>
		<xsl:value-of select="substring($date, 18, 2)" />
		<xsl:choose>
			<xsl:when test="number(substring($date, 12, 2)) &gt;= 12">
				<xsl:text> PM</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:text> AM</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:transform>
