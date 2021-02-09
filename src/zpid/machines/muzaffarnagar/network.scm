;;; Tyreunom's system administration and configuration tools.
;;;
;;; Copyright © 2019 Julien Lepiller <julien@lepiller.eu>
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;
;; Network configuration tools
;; taken from https://framagit.org/tyreunom/system-configuration/blob/master/modules/config/network.scm
;;

(define-module (zpid machines muzaffarnagar network)
  #:use-module (gnu packages linux)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (guix gexp))

(define (iproute2-shepherd-service config)
  (list (shepherd-service
	  (documentation "Run the iproute2 network service")
	  (provision '(networking))
	  (requirement '())
	  (start #~(lambda _
		     (let ((ip (string-append #$iproute "/sbin/ip"))
			   (dev "eno16777984"))
		       (invoke ip "a" "add" "136.199.86.65/25" "dev" dev)
		       (invoke ip "l" "set" dev "up")
		       ;(invoke ip "-6" "a" "add" "2a01:4f8:200:23ae::2/64" "dev" dev)
		       (invoke ip "r" "add" "default" "via" "136.199.86.1" "dev" dev)
		       ;(invoke ip "-6" "r" "add" "default" "via" "fe80::1" "dev" dev)
             )))
	  (stop #~(lambda _
		    (display "Connot stop iproute2 service.\n"))))))

(define iproute2-service-type
  (service-type (name 'static-networking)
		(extensions
		  (list
		    (service-extension shepherd-root-service-type
				       iproute2-shepherd-service)))
		(description "")))

(define-public static-network-service
  (service iproute2-service-type #t))

