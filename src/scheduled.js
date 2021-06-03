'use strict';

let Parser = require('rss-parser');

const readLobstersRss = (event) => {  
  const fun = async () => {
    const parser = new Parser();
    const newest = await parser.parseURL('https://lobste.rs/newest.rss');
    let lastSeen = new Date(0);
    
    try {
      const rawDate = await event.database.get('rss/lobsters');
      lastSeen = new Date(rawDate);
    } catch (e) {
      if(e.notFound) {
        // do nothing
      } else {
        event.logger.error(e);
      }
    }

    newest.items.forEach(item => {
      const { groups: { username } } = /\((?<username>.+)\)/i.exec(item.author);
      const publishedAt = new Date(item.isoDate);
      
      if (publishedAt > lastSeen) {
        lastSeen = publishedAt;
        
        event.logger.info('Broadcasting story.', {itemDate: item.isoDate, itemGuid: item.guid, lastSeen});
        
        let replyWithURL = `${item.title} {${item.link}} [${item.categories.join(' ')}] (${username}) ${item.guid}`;
        let replyWithoutURL = `${item.title} [${item.categories.join(' ')}] (${username}) ${item.guid}`;
        
        if(item.link === item.comments || replyWithURL.length > 510) {
          event.reply(replyWithoutURL);          
        }
        else {
          event.reply(replyWithURL);
        }
      }
    });
    
    await event.database.put('rss/lobsters', lastSeen.toISOString());
    return true;
  }
  
  return fun();
};
readLobstersRss.__interval__ = 5000;

module.exports = [
  readLobstersRss,
];
