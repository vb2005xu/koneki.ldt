--------------------------------------------------------------------------------
--  Copyright (c) 2012 Sierra Wireless.
--  All rights reserved. This program and the accompanying materials
--  are made available under the terms of the Eclipse Public License v1.0
--  which accompanies this distribution, and is available at
--  http://www.eclipse.org/legal/epl-v10.html
-- 
--  Contributors:
--       Kevin KIN-FOO <kkinfoo@sierrawireless.com>
--           - initial API and implementation and initial documentation
--------------------------------------------------------------------------------
return [[#
# --
# -- Inheritance
# --
#if _recordtypedef.supertype then
  <h$(i)> Extends $( fulllinkto(_recordtypedef.supertype)) </h$(i)>
#end
# --
# -- Descriptions
# --
#if _recordtypedef.shortdescription and #_recordtypedef.shortdescription > 0 then
	$( format( _recordtypedef.shortdescription ) )
#end
#if _recordtypedef.description and #_recordtypedef.description > 0 then
	$( format( _recordtypedef.description ) )
#end
# --
# -- Structure
# --
#if _recordtypedef.structurekind then
#  local structureLine = '<code><em>' .. prettyname(_recordtypedef)..'</em></code>'
#  if _recordtypedef.structurekind == "map" then
#    structureLine = structureLine .. ' is a map of <code><em>'
#
#    local keylink = linkto( _recordtypedef.defaultkeytyperef )
#    local keyname = prettyname( _recordtypedef.defaultkeytyperef )
#    if keylink then
#      structureLine = structureLine .. '<a href=\"' .. keylink .. '\">' .. keyname .. '</a>'
#    else
#      structureLine = structureLine .. keyname
#    end
#    structureLine = structureLine .. '</em></code> to <code><em>'
#
#  else
#    structureLine = structureLine .. ' is a list of <code><em>'
#  end
#
#  local valuelink = linkto( _recordtypedef.defaultvaluetyperef )
#  local valuename = prettyname( _recordtypedef.defaultvaluetyperef )
#  if valuelink then
#    structureLine = structureLine .. '<a href=\"' .. valuelink .. '\">' .. valuename .. '</a>'
#  else
#    structureLine = structureLine .. valuename
#  end
#
#  structureLine = structureLine ..'</em></code>. '.. _recordtypedef.structuredescription
	$( format(structureLine) )
#end
#--
#-- Describe usage
#--
#if _recordtypedef.metadata and _recordtypedef.metadata.usage then
	$( applytemplate(_recordtypedef.metadata.usage, i) )
#end
# --
# -- Describe type fields
# --
#if not isempty( _recordtypedef.fields ) then
	<h$(i)>Field(s)</h$(i)>
#	for name, item in sortedpairs( _recordtypedef.fields ) do
		$( applytemplate(item, i) )
#	end
#end ]]
