using System.Text.Json;
using backend.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Primitives;
using Xunit;

public class PublicWebsiteTests
{
    [Theory]
    [InlineData("157486", 2, "1574.86")]
    [InlineData("0", 2, "0")]
    [InlineData("1234", 3, "1.234")]
    public void WooCommerceMinorUnitsAreConvertedWithoutRounding(string amount, int units, string expected)
    {
        using var json = JsonDocument.Parse(JsonSerializer.Serialize(new
        {
            id = 1, name = "A &amp; B", prices = new { price = amount, currency_minor_unit = units },
            is_in_stock = true, is_purchasable = true,
        }));
        var product = PublicWebsiteClient.MapProduct(json.RootElement);
        Assert.Equal(decimal.Parse(expected, System.Globalization.CultureInfo.InvariantCulture), product.Price);
        Assert.Equal("A & B", product.Name);
        Assert.True(product.InStock);
    }

    [Fact]
    public void ProductFiltersTranslateToStoreApiNamesAndPriceMinorUnits()
    {
        var query = new QueryCollection(new Dictionary<string, StringValues>
        {
            ["q"] = "SICK sensor", ["category"] = "123", ["brand"] = "sick",
            ["minPrice"] = "12.34", ["maxPrice"] = "100", ["inStock"] = "true",
            ["pageSize"] = "500", ["sort"] = "price_asc",
        });
        var result = PublicWebsiteClient.ProductQuery(query);
        Assert.Equal("SICK sensor", result["search"]);
        Assert.Equal("1234", result["min_price"]);
        Assert.Equal("10000", result["max_price"]);
        Assert.Equal("100", result["per_page"]);
        Assert.Equal("sick", result["attributes[0][slug]"]);
        Assert.Equal("price", result["orderby"]);
        Assert.Equal("asc", result["order"]);
    }

    [Fact]
    public void ProjectParserIgnoresHeadingsWithoutLinksAndDeduplicatesCards()
    {
        const string markup = """
            <main><h1>Layihələr</h1>
              <article><img src="https://technocare.az/wp-content/uploads/a.webp">
                <h3><a href="/layiheler/test">Project one</a></h3><p>Actual work</p></article>
              <h3><a href="/layiheler/test">Duplicate</a></h3>
              <h3><a href="https://other.example/test">External link</a></h3>
            </main>
            """;
        var result = PublicWebsiteClient.ParseProjects(markup);
        Assert.Single(result);
        Assert.Equal("Project one", result[0].Name);
        Assert.Equal("Actual work", result[0].Description);
        Assert.Equal("https://technocare.az/wp-content/uploads/a.webp", result[0].ImageUrl);
        Assert.Equal(result[0].Id, PublicWebsiteClient.ParseProjects(markup)[0].Id);
    }
}
