<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:output omit-xml-declaration="yes" indent="no" />
	<xsl:param name="bulkTransform" />
	<xsl:param name="buddyIconDirectory" />
	<xsl:param name="buddyIconExtension" />

	<xsl:template match="/">
		<xsl:choose>
			<xsl:when test="count( /envelope/message ) &gt; 1">
				<xsl:apply-templates select="/envelope/message[last()]" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="event">
		<div class="event">
			<xsl:copy-of select="message/child::node()" />
			<xsl:if test="string-length( reason )">
				<span class="reason">
					<xsl:text> (</xsl:text>
					<xsl:apply-templates select="reason/child::node()" mode="copy"/>
					<xsl:text>)</xsl:text>
				</span>
			</xsl:if>
		</div>
	</xsl:template>

	<xsl:template match="envelope">
		<xsl:if test="not( @ignored = 'yes' ) and count( message[not( @ignored = 'yes' )] ) &gt;= 1">
			<xsl:variable name="messageClass">
				<xsl:choose>
					<xsl:when test="sender/@self = 'yes'">
						<xsl:text>selfMessage</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>message</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
	
			<xsl:variable name="bubbleClass">
				<xsl:choose>
					<xsl:when test="sender/@self = 'yes'">
						<xsl:text>rightBubble</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>leftBubble</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
	
			<table id="{@id}" class="{$messageClass}" cellpadding="0" cellspacing="0">
			<tr>
				<xsl:choose>
					<xsl:when test="sender/@self = 'yes'">
						<td class="gutter"></td>
					</xsl:when>
					<xsl:otherwise>
						<td class="icon">
						<xsl:choose>
							<xsl:when test="string-length( sender/@buddy )">
				     		   <img src="file://{concat( $buddyIconDirectory, sender/@buddy, $buddyIconExtension )}" width="32" height="32" alt="" onerror="this.src = 'person.tif'" />
							</xsl:when>
							<xsl:otherwise>
				     		   <img src="person.tif" width="32" height="32" alt="" />
							</xsl:otherwise>
						</xsl:choose>
						</td>
					</xsl:otherwise>
				</xsl:choose>
				<td>
					<table class="{$bubbleClass}" cellpadding="0" cellspacing="0">
					<tr>
						<td class="topLeft"></td>
						<td class="center" rowspan="2">
							<div class="text">
							<span>
							<xsl:if test="message[not( @ignored = 'yes' )][1]/@action = 'yes'">
								<span class="member action"><xsl:value-of select="sender" /></span><xsl:text> </xsl:text>
							</xsl:if>
							<xsl:copy-of select="message[not( @ignored = 'yes' )][1]/child::node()" />
							</span>
							<xsl:apply-templates select="message[not( @ignored = 'yes' )][position() &gt; 1]" />
							<xsl:if test="position() = last()">
								<div id="consecutiveInsert" />
							</xsl:if>
							</div>
						</td>
						<td class="topRight"></td>
					</tr>
					<tr>
						<td class="left"></td>
						<td class="right"></td>
					</tr>
					<tr>
						<td class="bottomLeft"></td>
						<td class="bottom"></td>
						<td class="bottomRight"></td>
					</tr>
					</table>
				</td>
				<xsl:choose>
					<xsl:when test="sender/@self = 'yes'">
						<td class="icon">
						<xsl:choose>
							<xsl:when test="string-length( sender/@buddy )">
				     		   <img src="file://{concat( $buddyIconDirectory, sender/@buddy, $buddyIconExtension )}" width="32" height="32" alt="" onerror="this.src = 'person.tif'" />
							</xsl:when>
							<xsl:otherwise>
				     		   <img src="person.tif" width="32" height="32" alt="" />
							</xsl:otherwise>
						</xsl:choose>
						</td>
					</xsl:when>
					<xsl:otherwise>
						<td class="gutter" rowspan="2"></td>
					</xsl:otherwise>
				</xsl:choose>
			</tr>
			<xsl:if test="not( sender/@self = 'yes' )">
				<tr>
					<td colspan="2" class="sender"><xsl:value-of select="sender" /></td>
				</tr>
			</xsl:if>
			</table>
		</xsl:if>
	</xsl:template>

	<xsl:template match="message">
		<xsl:choose>
			<xsl:when test="count( ../message[not( @ignored = 'yes' )] ) = 1 and not( @ignored = 'yes' )">
				<xsl:apply-templates select=".." />
			</xsl:when>
			<xsl:otherwise>
				<xsl:if test="not( @ignored = 'yes' ) and not( ../@ignored = 'yes' )">
					<hr />
					<span>
					<xsl:if test="@action = 'yes'">
						<span class="member action"><xsl:value-of select="../sender" /></span><xsl:text> </xsl:text>
					</xsl:if>
					<xsl:copy-of select="child::node()" /></span>
					<xsl:if test="not( $bulkTransform = 'yes' )">
						<xsl:processing-instruction name="message">type="subsequent"</xsl:processing-instruction>
						<div id="consecutiveInsert" />
					</xsl:if>
				</xsl:if>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:transform>
