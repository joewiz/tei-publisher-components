/* eslint-disable no-unused-expressions */
import { oneEvent, fixture, expect } from '@open-wc/testing';

import '../src/pb-search.js';

describe('serialize URL parameters', () => {
    it('serializes URL parameters', async () => {
        const el = (
            await fixture(`
            <pb-page endpoint="http://localhost:8080/exist/apps/tei-publisher">
              <pb-progress></pb-progress>
              <main>
                <pb-search id="search-form">
                      <div class="targets">
                          <paper-checkbox name="tei-target" value="tei-text" selected="selected">Search sections</paper-checkbox>
                          <paper-checkbox name="tei-target" value="tei-head" selected="selected">Search headings</paper-checkbox>
                      </div>
                  </pb-search>                  
                  <pb-load url="templates/search-results.html"></pb-load>
              </main>
            </pb-page>
            `)
        );
        const inputJSON = {
          "autocomplete-custom-template":undefined,
          "query":"test",
          "start":1,
          "tei-target":[
             "tei-text",
             "tei-head"
          ]
       };
       // console.log("json ", inputJSON);
        const searchForm = el.querySelector('#search-form');
        searchForm.setParameters(inputJSON);
        
        const queryString = window.TeiPublisher.url.search;
        // console.log("querystring:",queryString);
                
        expect(queryString).to.equal("?query=test&start=1&tei-target=tei-text&tei-target=tei-head");
        expect(queryString).to.not.equal("?query=test&start=1&tei-target=tei-text%2Ctei-head");
        
    });
});