/**
 * @file utility tools
 * @author leon(ludafa@outlook.com)
 */

export function guid() {
    return Math.random().toString(36).substr(2, 12);
}


export const querystring = {

    stringify(query) {
        return Object
            .keys(query)
            .map(function (key) {
                return `${encodeURIComponent(key)}=${encodeURIComponent(query[key])}`;
            })
            .join('&');
    }

};

export function pick(obj, predicate) {

    return Object
        .keys(obj)
        .reduce(function (result, key) {
            if (predicate(obj[key], key)) {
                result[key] = obj[key];
            }
            return result;
        }, {});

}
