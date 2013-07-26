window.onload = function() {
    var elems;
    var parent;

    // Modification of function by Dustin Diaz:
    //   http://www.dustindiaz.com/getelementsbyclass
    function getElementsByClass(searchClass,node,tag) {
        var classElements = [];
        if (node == null) {
            node = document;
        }
        if (tag == null) {
            tag = '*';
        }
        var els = node.getElementsByTagName(tag);
        var elsLen = els.length;
        var pattern = new RegExp("(^|\\s)" + searchClass + "(\\s|$)");
        var i = 0, j = 0;
        while (i < elsLen) {
            if ( pattern.test(els[i].className) ) {
                classElements[j] = els[i];
                j += 1;
            }
            i += 1;
        }
        return classElements;
    }

    // Derived from Remy Sharp's code:
    //   http://remysharp.com/2008/01/21/fixing-ie-overflow-problem/
    function fixOverflow(elems) {
        var i;
        for (i = 0; i < elems.length; i += 1) {
            // if the scrollWidth (the real width) is greater than the visible
            // width, then apply style changes
            if (elems[i].scrollWidth > elems[i].offsetWidth) {
                elems[i].style['paddingBottom'] = '20px';
                elems[i].style['overflowY'] = 'hidden';
            }
        }
    }

    parent = document.getElementById('sourcecode');
    if (!parent) {
        return;
    }

    elems = getElementsByClass('pas-source', parent);
    fixOverflow(elems);
}
