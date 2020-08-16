extends Node

# Dictionary of clients who we should transmit our updates to
# int (id), bool: yes or no sync
var clients_to_sync_with = {}

##
## Change-tracking signals
##

signal attribute_updated(attribute_name, value)
signal method_called(method_name, args)
